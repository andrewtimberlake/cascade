module Cascade
  class JobSpec
    include ::MongoMapper::Document
    set_collection_name 'cascade_jobs'

    key :class_name, String,  required: true
    key :arguments,  Array
    key :priority,   Integer, default: 1
    key :run_at,     Time,    default: -> { Time.now.utc }
    key :attempts,   Integer, default: 0
    key :locked_at,  Time
    key :locked_by,  String
    key :failed_at,  Time
    key :last_error, String
    key :re_run,     Boolean, default: false
    key :options,    Hash

    def self.failed
      where(:failed_at.ne => nil)
    end

    def self.find_available(num=10)
      right_now = Time.now.utc

      conditions = {
        failed_at: nil,
        locked_at: nil,
        run_at: {:$lte => right_now},
      }

      where(conditions).sort(priority: -1).limit(-num).all
    end

    def lock_exclusively!(worker_name)
      right_now = Time.now.utc

      conditions = {
        _id:       id,
        locked_at: nil,
        locked_by: nil,
      }
      result = collection.update(conditions, {:$set => {locked_at: right_now, locked_by: worker_name}})
      result['updatedExisting'] || result['nModified'] > 0
    end

    def job
      @job ||= class_name.constantize.new(*arguments)
    end

    def reset!
      update_attributes(failed_at:  nil,
                        last_error: nil,
                        locked_at:  nil,
                        locked_by:  nil,
                        attempts:   0)
    end
  end
end
