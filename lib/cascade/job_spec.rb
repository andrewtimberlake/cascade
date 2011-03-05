module Cascade
  class JobSpec
    def initialize(job)
      @class_name = job.class.name
      @arguments = job.instance_variable_get('@arguments')
    end

    attr_reader :class_name, :arguments
  end
end
