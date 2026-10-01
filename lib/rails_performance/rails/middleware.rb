module RailsPerformance
  module Rails
    class MiddlewareTraceStorerAndCleanup
      def initialize(app)
        @app = app
      end

      def call(env)
        dup.call!(env)
      end

      def call!(env)
        if %r{#{RailsPerformance.mount_at}}.match?(env["PATH_INFO"])
          RailsPerformance.skip = true
        end

        @status, @headers, @response = @app.call(env)

        if !RailsPerformance.skip
          RailsPerformance::Models::TraceRecord.new(
            request_id: CurrentRequest.current.request_id,
            value: CurrentRequest.current.tracings
          ).save
        end

        CurrentRequest.cleanup

        [@status, @headers, @response]
      end
    end

    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        dup.call!(env)
      end

      def call!(env)
        @status, @headers, @response = @app.call(env)

        # t = RailsPerformance::Utils.time
        if !RailsPerformance.skip
          if !CurrentRequest.current.ignore.include?(:performance) # grape is executed first, and than ignore regular future storage of "controller"-like request
            if (data = CurrentRequest.current.data)
              record = RailsPerformance::Models::RequestRecord.new(**data.merge({request_id: CurrentRequest.current.request_id}))

              # for 500 errors
              record.status ||= @status

              # capture referer from where this page was opened
              record.http_referer = env["HTTP_REFERER"] if record.status == 404
              record.remote_ip = ::ActionDispatch::Request.new(env).remote_ip
              record.device_type = Models::RequestRecord.device_type_for(env["HTTP_USER_AGENT"])

              # we can add custom data, for example Http User-Agent
              # or even devise current_user
              record.custom_data = request_custom_data(env)

              # store for section "recent requests"
              # store request information (regular rails request)
              record.save
            end
          end
        end
        # puts "==> store performance data: #{(RailsPerformance::Utils.time - t).round(3)}ms"

        [@status, @headers, @response]
      end

      private

      def request_custom_data(env)
        data = {}
        if RailsPerformance.capture_user_data && (user = env["warden"]&.user)
          user_name = user.try(:name).presence || user.try(:full_name).presence || user.try(:email).presence
          employer = user.try(:employer)
          employer = user.try(:employer_name) if employer.blank?
          employer = employer.try(:name).presence || employer if employer.present?
          data[:user_name] = user_name if user_name.present?
          data[:employer] = employer if employer.present?
        end

        return data unless RailsPerformance.custom_data_proc

        custom_data = RailsPerformance.custom_data_proc.call(env)
        data = data.merge(custom_data) if custom_data.is_a?(Hash)
        data.presence || custom_data
      end
    end
  end
end
