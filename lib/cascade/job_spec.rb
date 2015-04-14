module Cascade
  class JobSpec < ActiveRecord::Base
    self.table_name = 'cascade_jobs'

    def self.failed
      where.not(failed_at: nil)
    end

    def self.checkout_job(queue_name='default')
      find_by_sql(["SELECT * FROM cascade_lock_job(?)", queue_name]).first
    end

    def self.stats(queue_name=nil)
      query = Cascade::JobStats.all
      if queue_name
        query = query.where(queue: queue_name)
      end
      query
    end

    def job
      @job ||= job_class.constantize.new(*arguments)
    end

    def reset!
      update_attributes(failed_at:   nil,
                        error_count: 0,
                        last_error:  nil)
    end
  end
end
