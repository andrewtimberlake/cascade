module Cascade
  module Job
    module Callbacks
      def run_callbacks(action, job_spec)
        if self.class.instance_variable_defined?('@callbacks')
          callbacks = self.class.instance_variable_get('@callbacks')
          callbacks[action].each do |callback|
            if callback.is_a?(Symbol)
              send(callback, job_spec)
            else
              instance_exec job_spec, &callback
            end
          end
        end
      end

      module ClassMethods
        %w(before_queue before_run success error after_run).each do |action|
          define_method(action) do |*args, &block|
            add_callback(action.to_sym, args[0], &block)
          end
        end

        def add_callback(action, method = nil, &block)
          callbacks = @callbacks ||= Hash.new { |h,k| h[k] = [] }
          callbacks[action] << (method || block)
        end
      end
    end
  end
end
