require 'spec_helper'

module Cascade
  describe Master do
    def capture_output
      old_stdout = STDOUT.clone
      pipe_r, pipe_w = IO.pipe
      pipe_r.sync    = true
      output         = ""
      reader = Thread.new do
        begin
          loop do
            output << pipe_r.readpartial(1024)
          end
          rescue EOFError
        end
      end
      STDOUT.reopen(pipe_w)
      yield
    ensure
      STDOUT.reopen(old_stdout)
      pipe_w.close
      reader.join
      return output
    end

    before do
      $stdout.sync = true
    end

    it "master and all workers should exit on TERM" do
      output = capture_output do
        master = fork do
          Master.new(TestWorker).start(2)
        end
        sleep 0.2
        Process.kill(:TERM, master)
        Process.waitall
      end.split(/\n/)

      #puts "output: #{output.inspect}"
      output.should include("Starting worker 1")
      output.should include("Starting worker 2")
      output.should include("Stopping worker 1")
      output.should include("Stopping worker 2")
    end

    it "auto restarts a worker which dies" do
      output = capture_output do
        master = fork do
          Master.new(DyingWorker).start(2)
        end
        sleep 0.2
        Process.kill(:TERM, master)
        Process.waitall
      end.split(/\n/)

      #puts "output: #{output.inspect}"
      output.select{|line| line =~ /^Starting worker/ }.should have(4).lines
      output.should include("Dying worker 1")
    end

    it "adds a worker on SIGTTIN" do
      output = capture_output do
        master = fork do
          Master.new(TestWorker).start(2)
        end
        sleep 0.2
        Process.kill(:TTIN, master)
        sleep 0.2
        Process.kill(:TERM, master)
        Process.waitall
      end.split(/\n/)

      #puts "output: #{output.inspect}"
      output.select{|line| line =~ /^Starting worker/ }.should have(3).lines
      output.select{|line| line =~ /^Stopping worker/ }.should have(3).lines
    end

    it "removes a worker on SIGTTOU" do
      output = capture_output do
        master = fork do
          Master.new(TestWorker).start(2)
        end
        sleep 0.2
        Process.kill(:TTOU, master)
        sleep 0.2
        print "Should now have 1 process\n"
        sleep 0.2
        Process.kill(:TERM, master)
        Process.waitall
      end.split(/\n/)

      #puts "output: #{output.inspect}"
      output.should == ['Starting worker 1', 'Starting worker 2', 'Stopping worker 2', 'Should now have 1 process', 'Stopping worker 1']
    end
  end

  class TestWorker
    def initialize(number)
      @number = number
    end
    attr_reader :number

    def start
      print "Starting worker #{number}\n"
      run_loop
      print "Stopping worker #{number}\n"
    end

    def run_loop
      loop do
        sleep 0.1
        in_loop
        break if $exit
      end
    end

    def in_loop
      # Do nothing
    end
  end

  class DyingWorker < TestWorker
    def in_loop
      print "Dying worker #{number}\n"
      exit(1)
    end
  end

end
