require "test_helper"

class TrafficByIpReportTest < ActiveSupport::TestCase
  setup do
    reset_redis
  end

  test "groups recorded requests by IP and device type" do
    ["web", "mobile", "tablet"].each_with_index do |device_type, index|
      record = dummy_event
      record.remote_ip = "203.0.113.4"
      record.device_type = device_type
      record.custom_data = {user_name: index.zero? ? "Alex" : "Sam", employer: "Example Corp"}
      record.save
    end

    record = dummy_event
    record.remote_ip = "198.51.100.2"
    record.device_type = "mobile"
    record.custom_data = {user_name: "Alex", employer: "Other Corp"}
    record.save

    report = RailsPerformance::Reports::TrafficByIpReport.new(RailsPerformance::DataSource.new(type: :requests))

    assert_equal [
      {remote_ip: "203.0.113.4", web: 1, mobile: 1, tablet: 1, user_names: ["Alex", "Sam"], employers: ["Example Corp"], total: 3},
      {remote_ip: "198.51.100.2", web: 0, mobile: 1, tablet: 0, user_names: ["Alex"], employers: ["Other Corp"], total: 1}
    ], report.data
  end
end