require 'faraday'



module Saddle
  module Middleware
    module Request

      # Catches exceptions and retries each request a limited number of times.
      #
      # By default, it retries 0 times and performs exponential backoff, starting
      # at 50ms
      class Retry < Faraday::Middleware
        def initialize(app, ignored_exceptions=[])
          super(app)
          @ignored_exceptions = ignored_exceptions
        end

        def call(env)
          retries = env[:request][:num_retries] || 0
          backoff = env[:request][:retry_backoff] || 0.050 # in seconds
          begin
            @app.call(self.class.deep_copy(env))
          rescue => e
            # Only retry for GET or if the request is marked as idempotent
            if env[:method] == :get || env[:request][:idempotent]
              unless @ignored_exceptions.include?(e.class)
                # Retry a limited number of times
                if retries > 0
                  retries -= 1
                  sleep(backoff) if backoff > 0.0
                  backoff *= 2
                  retry
                end
              end
            end
            # Re-raise if we're out of retries or it's not handled
            raise
          end
        end

        def self.deep_copy(value)
          if value.is_a?(Hash)
            result = value.clone
            value.each{|k, v| result[k] = deep_copy(v)}
            result
          elsif value.is_a?(Array)
            result = value.clone
            result.clear
            value.each{|v| result << deep_copy(v)}
            result
          else
            value
          end
        end
      end

    end
  end
end
