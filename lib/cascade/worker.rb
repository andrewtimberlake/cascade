module Cascade
  class Worker
    def self.start
      trap('TERM') { $exit = true }
      trap('INT') { $exit = true }

      loop do
        result = run

        break if $exit

        count = result.sum
        if count.zero?
          sleep(5)
        end

        break if $exit
      end
    end

    def self.run
      success = 0
      failure = 0

      find_available.each do |job_spec|
        break if $exit
        if lock_exclusively!(job_spec)
          if run_forked(job_spec)
            success += 1
          else
            failure += 1
          end
        end
      end

      [success, failure]
    end

    def self.run_forked(job_spec)
      read, write = IO.pipe

      pid = fork do
        job = job_spec.job
        $0 = "Cascade::Job : #{name} : #{job.describe}"
        if run_job(job_spec, job)
          write.puts '1'
        else
          write.puts '0'
        end
      end
      write.close
      result = read.read.strip
      pid, status = Process.wait2(pid)

      if status.exitstatus != 0
        job_spec.reload
        job_spec.update_attributes(:last_error => 'Child process failure',
                                   :failed_at => Time.now.utc)
      end

      return result == '1'
    end

    def self.run_job(job_spec, job)
      job_spec.re_run = false
      completed_successully = true
      begin
        job.run_callbacks(:before_run, job_spec)

        job.run

        job.run_callbacks(:on_success, job_spec)

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

    def self.enqueue(class_name, *args)
      job_spec = JobSpec.new(:class_name => class_name,
                             :arguments => args,
                             :run_at => Time.now.utc,
                             :priority => 1)

      job = job_spec.job
      job.run_callbacks(:before_queue, job_spec)

      job_spec.save!
      job_spec
    end

    def self.name=(name)
      @name = name
    end

    def self.name
      @name ||= generate_name
    end

    def self.generate_name
      "#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"
    end

    private
      def self.find_available(num = 10)
        right_now = Time.now.utc

        conditions = {
          :run_at => {'$lte' => right_now},
          :failed_at => nil,
          :locked_at => nil
        }

        job_specs = JobSpec.where(conditions).limit(-num).sort([[:priority, 1], [:run_at, 1]]).all
        job_specs
      end

      def self.lock_exclusively!(job_spec)
        right_now = Time.now.utc

        conditions = {
          :_id => job_spec.id,
          :locked_at => nil,
          :locked_by => nil,
          :run_at => {'$lte' => right_now}
        }
        job_spec.collection.update(conditions, {'$set' => {:locked_at => right_now, :locked_by => name}})
        affected_rows = job_spec.collection.find({:_id => job_spec.id, :locked_by => name}).count
        if affected_rows == 1
          job_spec.locked_at = right_now
          job_spec.locked_by = name
          true
        else
          false
        end
      end
  end
end
