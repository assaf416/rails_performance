require_relative "base_controller"

module RailsPerformance
  class RailsPerformanceController < RailsPerformance::BaseController
    protect_from_forgery except: :recent

    if RailsPerformance.enabled
      def index
        @datasource = RailsPerformance::DataSource.new(**prepare_query(params), type: :requests)
        users_datasource = RailsPerformance::DataSource.new(type: :requests, q: @datasource.q.except(:user_name))
        @user_names = users_datasource.db.data
          .map { |record| record.record_hash["user_name"] || record.record_hash[:user_name] }
          .compact
          .uniq
          .sort

        @widgets = RailsPerformance.dashboard_charts.map do |row|
          if row.is_a?(Array)
            row.map { |class_name| Widgets.const_get(class_name).new(@datasource) }
          else
            Widgets.const_get(row).new(@datasource)
          end
        end

        respond_to do |format|
          format.html
          format.json { send_json_download "index", page: "index", widgets: widgets_json(@widgets) }
        end
      end

      def resources
        @datasource = RailsPerformance::DataSource.new(**prepare_query(params), type: :resources, days: RailsPerformance::Utils.days(RailsPerformance.system_monitor_duration))
        db = @datasource.db

        @resources_report = RailsPerformance::Reports::ResourcesReport.new(db)

        respond_to do |format|
          format.html
          format.json do
            servers = @resources_report.servers.map do |server|
              {name: server.name, widgets: widgets_json(server.charts)}
            end
            send_json_download "resources", page: "resources", servers: servers
          end
        end
      end

      def summary
        @datasource = RailsPerformance::DataSource.new(**prepare_query(params), type: :requests)
        db = @datasource.db

        @throughput_report_data = RailsPerformance::Reports::ThroughputReport.new(db).data
        @response_time_report_data = RailsPerformance::Reports::ResponseTimeReport.new(db).data
        @data = RailsPerformance::Reports::BreakdownReport.new(db, title: "Requests").data
        respond_to do |format|
          format.js {}
          format.json do
            send_json_download "summary", page: "summary", data: {
              throughput: @throughput_report_data,
              response_time: @response_time_report_data,
              breakdown: @data
            }
          end
          format.any do
            render plain: "Doesn't open in new window. Wait until full page load."
          end
        end
      end

      def trace
        @record = RailsPerformance::Models::RequestRecord.find_by(request_id: params[:id])
        @data = RailsPerformance::Reports::TraceReport.new(request_id: params[:id]).data
        respond_to do |format|
          format.js {}
          format.json { send_json_download "trace_#{params[:id]}", page: "trace", record: @record&.record_hash, data: @data }
          format.any do
            render plain: "Doesn't open in new window. Wait until full page load."
          end
        end
      end

      def crashes
        @datasource = RailsPerformance::DataSource.new(**prepare_query({status_eq: 500}), type: :requests)
        @table = Widgets::CrashesTable.new(@datasource)

        respond_to do |format|
          format.html
          format.csv do
            export_to_csv "error_report", @table.data
          end
          format.json { send_json_download "crashes", page: "crashes", data: @table.data }
        end
      end

      def requests
        @datasource = RailsPerformance::DataSource.new(**prepare_query(params), type: :requests)
        @table = Widgets::RequestsTable.new(@datasource)

        respond_to do |format|
          format.html
          format.csv do
            export_to_csv "requests_report", @table.data
          end
          format.json { send_json_download "requests", page: "requests", data: @table.data }
        end
      end

      def recent
        @datasource = RailsPerformance::DataSource.new(**prepare_query(params), type: :requests)
        @table = Widgets::RecentRequestsTable.new(@datasource)

        respond_to do |format|
          format.html
          format.csv do
            export_to_csv "recent_requests_report", @table.data
          end
          format.json { send_json_download "recent", page: "recent", data: @table.data }
        end
      end

      def slow
        @datasource = RailsPerformance::DataSource.new(**prepare_query(params), type: :requests)
        @table = Widgets::SlowRequestsTable.new(@datasource)

        respond_to do |format|
          format.html
          format.csv do
            export_to_csv "slow_requests_report", @table.data
          end
          format.json { send_json_download "slow", page: "slow", data: @table.data }
        end
      end

      def sidekiq
        @datasource = RailsPerformance::DataSource.new(**prepare_query(params), type: :sidekiq)
        @widgets = [
          Widgets::ThroughputChart.new(@datasource, subtitle: "Sidekiq Workers Throughput Report", legend: "Jobs", units: "jobs / minute"),
          Widgets::ResponseTimeChart.new(@datasource, subtitle: "Average Execution Time"),
          Widgets::SidekiqJobsTable.new(@datasource)
        ]

        respond_to do |format|
          format.html
          format.json { send_json_download "sidekiq", page: "sidekiq", widgets: widgets_json(@widgets) }
        end
      end

      def delayed_job
        @datasource = RailsPerformance::DataSource.new(**prepare_query(params), type: :delayed_job)
        @widgets = [
          Widgets::ThroughputChart.new(@datasource, subtitle: "Delayed::Job Workers Throughput Report", legend: "Jobs", units: "jobs / minute"),
          Widgets::ResponseTimeChart.new(@datasource, subtitle: "Average Execution Time"),
          Widgets::DelayedJobTable.new(@datasource)
        ]

        respond_to do |format|
          format.html
          format.json { send_json_download "delayed_job", page: "delayed_job", widgets: widgets_json(@widgets) }
        end
      end

      def custom
        @datasource = RailsPerformance::DataSource.new(**prepare_query(params), type: :custom)
        @widgets = [
          Widgets::CustomEventsTable.new(@datasource),
          Widgets::ThroughputChart.new(@datasource, subtitle: "Custom Events Throughput Report", legend: "Events", units: "events / minute"),
          Widgets::ResponseTimeChart.new(@datasource, subtitle: "Average Execution Time")
        ]

        respond_to do |format|
          format.html
          format.json { send_json_download "custom", page: "custom", widgets: widgets_json(@widgets) }
        end
      end

      def grape
        @datasource = RailsPerformance::DataSource.new(**prepare_query(params), type: :grape)
        @widgets = [
          Widgets::ThroughputChart.new(@datasource, subtitle: "Grape Throughput Report"),
          Widgets::GrapeRequestsTable.new(@datasource)
        ]

        respond_to do |format|
          format.html
          format.json { send_json_download "grape", page: "grape", widgets: widgets_json(@widgets) }
        end
      end

      def rake
        @datasource = RailsPerformance::DataSource.new(**prepare_query(params), type: :rake)
        @widgets = [
          Widgets::RakeTasksTable.new(@datasource),
          Widgets::ThroughputChart.new(@datasource, subtitle: "Rake Throughput Report", legend: "Tasks", units: "tasks / minute")
        ]

        respond_to do |format|
          format.html
          format.json { send_json_download "rake", page: "rake", widgets: widgets_json(@widgets) }
        end
      end

      private

      def send_json_download(filename, payload)
        send_data JSON.pretty_generate(payload),
          filename: "#{filename}_#{Time.zone.today}.json",
          type: "application/json",
          disposition: "attachment"
      end

      def widgets_json(widgets)
        Array(widgets).flatten.map do |widget|
          {
            type: widget.class.name.demodulize,
            title: widget.respond_to?(:subtitle) ? widget.subtitle : nil,
            description: widget.respond_to?(:description) ? widget.description : nil,
            legend: widget.respond_to?(:legend) ? widget.legend : nil,
            units: widget.respond_to?(:units) ? widget.units : nil,
            data: widget.respond_to?(:data) ? widget.data : widget_value(widget)
          }
        end
      end

      def widget_value(widget)
        return unless widget.respond_to?(:value)

        {label: widget.label, value: widget.value}
      end

      def prepare_query(query = {})
        RailsPerformance::Rails::QueryBuilder.compose_from(query)
      end
    end
  end
end
