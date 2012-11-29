require 'kgio'

module Cascade
  class Master
    def initialize(worker_class=Worker)
      @worker_class = worker_class
    end
    attr_reader :worker_class
    attr_accessor :children

    CHILDREN = []
    SIG_QUEUE = []
    SELF_PIPE = []

    def start(workers=2)
      init_self_pipe!

      [:TERM, :INT, :QUIT, :TTIN, :TTOU, :CHLD].each do |sig|
        trap(sig) do
          SIG_QUEUE << sig
          awaken_master
        end
      end

      (0..workers-1).each do |i|
        CHILDREN << fork_worker(i)
      end

      loop do
        process_signals
        break if $exit
        master_sleep
        break if $exit
      end

      Process.waitall
    end

    def init_self_pipe!
      SELF_PIPE.each { |io| io.close rescue nil }
      SELF_PIPE.replace(Kgio::Pipe.new)
      SELF_PIPE.each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
    end

    def awaken_master
      SELF_PIPE[1].kgio_trywrite('.') # wakeup master process from select
    end

    def master_sleep(sec=2)
      IO.select([ SELF_PIPE[0] ], nil, nil, sec) or return
      SELF_PIPE[0].kgio_tryread(11)
    end

    def process_signals
      while true
        case SIG_QUEUE.shift
        when nil
          return true
        when :TERM, :INT, :QUIT
          stop
        when :TTIN
          CHILDREN << fork_worker(CHILDREN.size)
        when :TTOU
          pid = CHILDREN.pop
          Process.kill(:QUIT, pid)
        when :CHLD
          reap_all_workers
        end
      end
    end

    def stop
      CHILDREN.each do |pid|
        Process.kill(:QUIT, pid)
      end
      $exit = true
    end

    def reap_all_workers
      begin
        while pid = Process.wait(-1, Process::WNOHANG)
          index = CHILDREN.index(pid)
          break unless index #If we're reducing the children through SIGTTOU then we won't find the child and we don't want to refork
          unless $exit
            CHILDREN[index] = fork_worker(index)
          end
        end
      rescue Errno::ECHILD
        #Ignore if we have no children
      end
    end

    def fork_worker(number)
      fork do
        [:TTIN, :TTOU].each do |sig|
          trap(sig) {}
        end
        [:TERM, :INT, :QUIT].each do |sig|
          trap(sig) do
            $exit = true
          end
        end
        worker_class.new(number+1).start
      end
    end
  end
end
