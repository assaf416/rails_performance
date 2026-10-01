require "test_helper"

class RailsPerformance::Test < ActiveSupport::TestCase
  test "datastore" do
    setup_db
    ds = RailsPerformance::DataSource.new(q: {}, type: :requests)
    assert_not_nil ds.db
  end

  test "report RequestsReport - ControllerActionReport and group" do
    setup_db

    ds = RailsPerformance::DataSource.new(q: {}, type: :requests)
    assert_not_nil RailsPerformance::Reports::RequestsReport.new(ds.db, group: :controller_action).data
    assert_not_nil RailsPerformance::Reports::RequestsReport.new(ds.db, group: :controller).data
    assert_not_nil RailsPerformance::Reports::RequestsReport.new(ds.db, group: :controller_action_format).data
    assert_not_nil RailsPerformance::Reports::RequestsReport.new(ds.db, group: :controller_action_format, sort: :db_runtime_slowest).data
  end

  test "requests report includes distinct user names and employers" do
    first = dummy_event(controller: "Users", action: "index")
    first.custom_data = {user_name: "Alex", employer: "Example Corp"}
    first.save

    second = dummy_event(controller: "Users", action: "index")
    second.custom_data = {user_name: "Sam", employer: "Example Corp"}
    second.save

    datasource = RailsPerformance::DataSource.new(type: :requests)
    report = RailsPerformance::Reports::RequestsReport.new(datasource.db, group: :controller_action_format)

    assert_equal ["Alex", "Sam"], report.data.first[:user_names]
    assert_equal ["Example Corp"], report.data.first[:employers]
  end

  test "report ThroughputReport" do
    setup_db

    ds = RailsPerformance::DataSource.new(q: {}, type: :requests)
    assert_not_nil RailsPerformance::Reports::ThroughputReport.new(ds.db).data
  end

  test "report ResponseTimeReport" do
    setup_db

    ds = RailsPerformance::DataSource.new(q: {}, type: :requests)
    assert_not_nil RailsPerformance::Reports::ResponseTimeReport.new(ds.db).data
  end

  test "report TraceReport" do
    setup_db(dummy_event(request_id: "112233"))

    RailsPerformance::Models::TraceRecord.new(request_id: "112233", value: [{x: 1}, {y: 2}]).save
    assert_equal RailsPerformance::Reports::TraceReport.new(request_id: "112233").data, [{"x" => 1}, {"y" => 2}]
  end
end
