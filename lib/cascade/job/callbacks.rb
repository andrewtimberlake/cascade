module Cascade
  module Job
    module Callbacks
      def run_callbacks(action, job_spec)
        self.class.all_callbacks[action].each do |callback|
          result = if callback.is_a?(Symbol)
                     send(callback, job_spec)
                   else
                     instance_exec job_spec, &callback
                   end
          return false unless result
        end
        true
      end

      module ClassMethods
        def run_callbacks(action, job_spec)
          all_callbacks[action].each do |callback|
            result = if callback.is_a?(Symbol)
                       send(callback, job_spec)
                     else
                       callback.call(job_spec)
                     end
            return false unless result
          end
          true
        end

        %w(before_queue before_fork after_fork before_run on_success on_error after_run).each do |action|
          define_method(action) do |*args, &block|
            add_callback(action.to_sym, args[0], &block)
          end
        end

        def callbacks
          @callbacks ||= Hash.new { |h,k| h[k] = [] }
        end

        def all_callbacks
          if superclass.respond_to?(:callbacks)
            callbacks.merge superclass.send(:all_callbacks) do |key, old_val, new_val|
              new_val + old_val
            end
          else
            callbacks
          end
        end

        def add_callback(action, method = nil, &block)
          callbacks[action] << (method || block)
        end
      end
    end
  end
end
