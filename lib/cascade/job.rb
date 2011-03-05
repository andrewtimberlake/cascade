require 'cascade/job/callbacks'

module Cascade
  class Job
    include Callbacks

    def initialize(args = {})
      @arguments = args
    end

    def run
      true
    end

    def describe
      self.class.name
    end

    def spec
      JobSpec.new(self)
    end

    def self.enqueue(job)
      Queue.enqueue(job)
    end
  end
end
