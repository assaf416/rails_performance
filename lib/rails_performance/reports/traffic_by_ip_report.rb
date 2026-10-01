module RailsPerformance
  module Reports
    class TrafficByIpReport
      DEVICE_TYPES = %w[web mobile tablet].freeze

      def initialize(datasource)
        @datasource = datasource
      end

      def data
        @datasource.db.data
          .select { |record| record.remote_ip.present? }
          .group_by(&:remote_ip)
          .map do |remote_ip, records|
            counts = records.each_with_object(Hash.new(0)) do |record, result|
              device_type = DEVICE_TYPES.include?(record.device_type) ? record.device_type : "web"
              result[device_type] += 1
            end
            {
              remote_ip: remote_ip,
              web: counts["web"],
              mobile: counts["mobile"],
              tablet: counts["tablet"],
              user_names: distinct_custom_values(records, "user_name"),
              employers: distinct_custom_values(records, "employer"),
              total: records.size
            }
          end
          .sort_by { |entry| [-entry[:total], entry[:remote_ip]] }
      end

      private

      def distinct_custom_values(records, key)
        records.map { |record| record.record_hash[key] }.compact.uniq.sort
      end
    end
  end
end