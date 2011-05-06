require 'cascade/job/callbacks'

module Cascade
  module Job
    include Callbacks

    def self.included(mod)
      mod.extend(ClassMethods)
    end

    def run
      true
    end

    def describe
      self.class.name
    end

    module ClassMethods
      include Callbacks::ClassMethods

      def enqueue(*args)
        Worker.enqueue(name, *args)
      end
    end
  end
end
