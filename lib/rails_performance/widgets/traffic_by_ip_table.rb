module RailsPerformance
  module Widgets
    class TrafficByIpTable < Table
      def subtitle
        "Requests by IP and device"
      end

      def data
        @data ||= RailsPerformance::Reports::TrafficByIpReport.new(datasource).data
      end

      def empty_message
        "No request IP data recorded yet."
      end

      def content_partial_path
        "rails_performance/rails_performance/traffic_by_ip_table_content"
      end
    end
  end
end