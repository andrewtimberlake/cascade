module Cascade
  class Queue
    def self.run
      job_specs.delete_if do |job_spec|
        pid = fork do
          job = const_get(job_spec.class_name).new(job_spec.arguments)
          $0 = "Cascade::Job : #{job.describe}"
          begin
            job.send_callbacks(:before_run, job_spec)
            job.run
            job.send_callbacks(:success, job_spec)
          rescue
            job.send_callbacks(:error, job_spec, $!)
            false
          ensure
            job.send_callbacks(:after_run, job_spec)
          end
        end
        Process.wait(pid)
        true
      end
    end

    def self.job_specs
      @job_specs ||= []
    end

    def self.enqueue(job)
      spec = job.spec
      job.run_callbacks(:before_queue, spec)
      job_specs << spec
    end
  end
end
