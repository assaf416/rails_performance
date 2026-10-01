require "test_helper"

class RequestRecordTest < ActiveSupport::TestCase
  test "storing" do
    assert_nothing_raised do
      record = dummy_event
      record.save
    end
  end

  test "stores remote IP and device type" do
    record = dummy_event
    record.remote_ip = "203.0.113.4"
    record.device_type = "mobile"
    record.save

    stored = RailsPerformance::Models::RequestRecord.find_by(request_id: record.request_id)
    assert_equal "203.0.113.4", stored.remote_ip
    assert_equal "mobile", stored.device_type
    assert_equal "203.0.113.4", stored.record_hash[:remote_ip]
    assert_equal "mobile", stored.record_hash[:device_type]
  end

  test "classifies user agents by device type" do
    assert_equal "web", RailsPerformance::Models::RequestRecord.device_type_for("Mozilla/5.0 (X11; Linux x86_64) Chrome/120.0 Safari/537.36")
    assert_equal "mobile", RailsPerformance::Models::RequestRecord.device_type_for("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148")
    assert_equal "tablet", RailsPerformance::Models::RequestRecord.device_type_for("Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15")
  end

  test "record" do
    RailsPerformance.duration = 3.hours

    key = "performance|controller|HomeController|action|index|format|html|status|200|datetime|20200124T0531|datetimei|1579861868|method|GET|path|/|request_id|1fb7f6c4d874e10644e1259ac44b514e|END"
    value = '{"view_runtime":null,"db_runtime":0,"duration":27.329741000000002,"http_referer":null,"exception":"ZeroDivisionError divided by 0","backtrace":["/root/projects/rails_performance/test/dummy/app/controllers/account/site_controller.rb:17:in `/\'","/root/projects/rails_performance/test/dummy/app/controllers/account/site_controller.rb:17:in `crash\'","/usr/local/rvm/gems/ruby-2.6.3/gems/actionpack-6.1.3.1/lib/action_controller/metal/basic_implicit_render.rb:6:in `send_action\'"]}'

    record = RailsPerformance::Models::RequestRecord.from_db(key, value)
    assert_equal record.controller, "HomeController"
    assert_equal record.status, "200"
    assert_equal record.value["duration"], 27.329741000000002
    assert_equal record.value["exception"], "ZeroDivisionError divided by 0"
    assert_equal record.value["backtrace"].class, Array
    assert_equal record.value["backtrace"].size, 3
    assert_equal record.request_id, "1fb7f6c4d874e10644e1259ac44b514e"

    record = RailsPerformance::Models::RequestRecord.from_db(key, nil)
    assert_equal record.controller, "HomeController"
    assert_equal record.status, "200"
    assert_nil record.value["duration"]
  end
end
