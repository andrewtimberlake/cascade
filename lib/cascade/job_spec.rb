module Cascade
  class JobSpec
    include ::MongoMapper::Document
    set_collection_name 'cascade_jobs'

    key :class_name, String, :required => true
    key :arguments, Array
    key :priority, Integer, :default => 1
    key :run_at, Time, :default => lambda { Time.now.utc }
    key :locked_at, Time
    key :locked_by, String
    key :failed_at, Time

    def job
      @job ||= class_name.constantize.new(*arguments)
    end
  end
end
