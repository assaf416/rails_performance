require "test_helper"

class MiddlewareTest < ActiveSupport::TestCase
  test "captures user and employer details alongside configured custom data" do
    original_capture_user_data = RailsPerformance.capture_user_data
    original_custom_data_proc = RailsPerformance.custom_data_proc
    employer = Struct.new(:name).new("Example Corp")
    user = Struct.new(:name, :email, :employer).new("Alex", "alex@example.com", employer)
    warden = Struct.new(:user).new(user)
    RailsPerformance.capture_user_data = true
    RailsPerformance.custom_data_proc = proc { {source: "host"} }
    middleware = RailsPerformance::Rails::Middleware.new(->(_env) { [200, {}, []] })

    assert_equal(
      {user_name: "Alex", employer: "Example Corp", source: "host"},
      middleware.send(:request_custom_data, "warden" => warden)
    )
  ensure
    RailsPerformance.capture_user_data = original_capture_user_data
    RailsPerformance.custom_data_proc = original_custom_data_proc
  end

  test "does not capture identity when disabled" do
    original_capture_user_data = RailsPerformance.capture_user_data
    original_custom_data_proc = RailsPerformance.custom_data_proc
    RailsPerformance.capture_user_data = false
    RailsPerformance.custom_data_proc = nil
    user = Struct.new(:name, :email, :employer).new("Alex", "alex@example.com", nil)
    warden = Struct.new(:user).new(user)
    middleware = RailsPerformance::Rails::Middleware.new(->(_env) { [200, {}, []] })

    assert_equal({}, middleware.send(:request_custom_data, "warden" => warden))
  ensure
    RailsPerformance.capture_user_data = original_capture_user_data
    RailsPerformance.custom_data_proc = original_custom_data_proc
  end

  test "persists captured identity on the request record" do
    original_capture_user_data = RailsPerformance.capture_user_data
    original_custom_data_proc = RailsPerformance.custom_data_proc
    RailsPerformance.capture_user_data = true
    RailsPerformance.custom_data_proc = nil

    request_id = RailsPerformance::CurrentRequest.current.request_id
    RailsPerformance::CurrentRequest.current.data = {
      controller: "Home",
      action: "index",
      format: "html",
      status: 200,
      datetime: RailsPerformance::Utils.time.strftime(RailsPerformance::FORMAT),
      datetimei: RailsPerformance::Utils.time.to_i,
      method: "GET",
      path: "/"
    }
    employer = Struct.new(:name).new("Example Corp")
    user = Struct.new(:full_name, :employer).new("Alex Example", employer)
    warden = Struct.new(:user).new(user)
    env = {
      "PATH_INFO" => "/",
      "REQUEST_METHOD" => "GET",
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_USER_AGENT" => "",
      "warden" => warden
    }
    middleware = RailsPerformance::Rails::Middleware.new(->(_env) { [200, {}, []] })

    middleware.call(env)

    record = RailsPerformance::Models::RequestRecord.find_by(request_id: request_id)
    assert_equal "Alex Example", record.record_hash["user_name"]
    assert_equal "Example Corp", record.record_hash["employer"]
  ensure
    RailsPerformance.capture_user_data = original_capture_user_data
    RailsPerformance.custom_data_proc = original_custom_data_proc
    RailsPerformance::CurrentRequest.cleanup
  end
end
