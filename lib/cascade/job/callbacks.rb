module Cascade
  module Job
    module Callbacks
      def run_callbacks(action, job_spec)
        self.class.callbacks[action].each do |callback|
          if callback.is_a?(Symbol)
            send(callback, job_spec)
          else
            instance_exec job_spec, &callback
          end
        end
      end

      module ClassMethods
        %w(before_queue before_run on_success on_error after_run).each do |action|
          define_method(action) do |*args, &block|
            add_callback(action.to_sym, args[0], &block)
          end
        end

        def callbacks
          @callbacks ||= if superclass.respond_to?(:callbacks)
            superclass.send(:callbacks)
          else
            Hash.new { |h,k| h[k] = [] }
          end
        end

        def add_callback(action, method = nil, &block)
          callbacks[action] << (method || block)
        end
      end
    end
  end
end
