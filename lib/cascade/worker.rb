module Cascade
  class Worker
    attr_reader :number
    attr_accessor :child_pid, :proc_name

    def self.configure(&block)
      instance_eval(&block)
    end

    def self.before_fork(&block)
      @before_fork = block
    end

    def self.after_fork(&block)
      @after_fork = block
    end

    def initialize(number)
      @number = number
      self.child_pid = nil
    end

    def start
      self.proc_name = $0
      set_proc_name
      setup_signal_handlers

      loop do
        break if $exit
        call_before_fork
        self.child_pid = fork do
          call_after_fork
          setup_signal_handlers

          completed_jobs = 0
          until completed_jobs >= 50
            break if $exit
            result = run
            set_proc_name # Re-set it because each job changes to show the job being run
            count = result.sum
            completed_jobs += count
            sleep(5) if count.zero? && !$exit
          end
        end
        pid, status = Process.wait2(child_pid)
        self.child_pid = nil
      end
    end

    def run
      success = 0
      failure = 0

      find_available.each do |job_spec|
        break if $exit
        if lock_exclusively!(job_spec)
          if run_job(job_spec)
            success += 1
          else
            failure += 1
          end
        end
      end

      [success, failure]
    end

    def run_job(job_spec)
      job = job_spec.job
      $0 = "Cascade::Job : #{name} : #{job.describe}"

      job_spec.re_run = false
      completed_successully = true
      begin
        if completed_successully = job.run_callbacks(:before_run, job_spec)
          job.run
          job.run_callbacks(:on_success, job_spec)
        end
      rescue ReRun => ex
        completed_successully = false
      rescue Exception => ex
        job_spec.last_error = [ex, ex.backtrace].flatten.join("\n")
        job_spec.failed_at = Time.now.utc

        job.run_callbacks(:on_error, job_spec)

        completed_successully = false
      ensure
        job.run_callbacks(:after_run, job_spec)

        job_spec.locked_by = nil
        job_spec.locked_at = nil
      end
      if completed_successully && !job_spec.re_run?
        job_spec.destroy
      else
        job_spec.save!
      end
      completed_successully
    end

    def self.enqueue(job_class, *args)
      priority, run_at = nil

      options = args[-1]
      if options.respond_to?(:keys)
        priority     = options.delete(:priority)
        run_at       = options.delete(:run_at)
        job_options  = options.delete(:options)
        args.pop if options.size == 0
      end

      job_spec = JobSpec.new(
                         class_name: job_class.name,
                         arguments:  args,
                         run_at:     run_at      || Time.now.utc,
                         priority:   priority    || 1,
                         options:    job_options || {}
                         )

      job = job_spec.job
      job.run_callbacks(:before_queue, job_spec)

      job_spec.save!
      job_spec
    end

    def name=(name)
      @name = name
    end

    def name
      @name ||= generate_name
    end

    def generate_name
      "#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"
    end

    MAP_FUNCTION = <<-MAP
      function () {
        emit(this.class_name, {count:1, running:this.locked_at == null ? 0 : 1, failed:this.failed_at == null ? 0 : 1});
      }
    MAP

    REDUCE_FUNCTION = <<-REDUCE
      function (k, v) {
        obj = {count:0, running:0, failed:0};
        for (var i in v) {
          obj.count += v[i].count;
          obj.running += v[i].running;
          obj.failed += v[i].failed;
        }
        return obj;
      }
    REDUCE

    def self.queue
      results = JobSpec.collection.map_reduce MAP_FUNCTION, REDUCE_FUNCTION, out: {inline: 1}, raw: true
      results['results'].inject({}){|m,e| m[e['_id']] = {count: e['value']['count'].to_i, running: e['value']['running'].to_i, failed: e['value']['failed'].to_i}; m }
    end

    private
    def find_available(num = 10)
      right_now = Time.now.utc

      conditions = {
        run_at: {'$lte' => right_now},
        failed_at: nil,
        locked_at: nil
      }

      job_specs = JobSpec.where(conditions).limit(-num).sort([[:priority, -1], [:run_at, 1]]).all
      job_specs
    end

    def lock_exclusively!(job_spec)
      right_now = Time.now.utc

      conditions = {
        _id:       job_spec.id,
        locked_at: nil,
        locked_by: nil,
        run_at:    {'$lte' => right_now}
      }
      job_spec.collection.update(conditions, {'$set' => {locked_at: right_now, locked_by: name}})
      affected_rows = job_spec.collection.find({_id: job_spec.id, locked_by: name}).count
      if affected_rows == 1
        job_spec.locked_at = right_now
        job_spec.locked_by = name
        true
      else
        false
      end
    end

    def call_before_fork
      callback = self.class.instance_variable_get("@before_fork")
      return unless callback
      callback.call
    end

    def call_after_fork
      callback = self.class.instance_variable_get("@after_fork")
      return unless callback
      callback.call
    end

    def set_proc_name
      $0 = [proc_name.sub(/master/, '').strip, "worker #{number}"].join(' ')
    end

    def setup_signal_handlers
      # puts "Setting up signal handlers for #{Process.pid}"
      [:INT, :TERM, :QUIT].each do |sig|
        trap(sig) do
          begin
            Process.kill(sig, child_pid) if child_pid
          rescue Errno::ENOENT, Errno::ESRCH
            # Child already dead
          end
          # puts "#{sig}: exiting #{Process.pid}"
          $exit = true
        end
      end
    end
  end
end
