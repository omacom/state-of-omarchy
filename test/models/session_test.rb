require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "new sessions start active with last_active_at set" do
    session = Session.create!(user: users(:taha))
    assert_not session.expired?
    assert_in_delta Time.current, session.last_active_at, 1.second
  end

  test "expires after the idle timeout" do
    session = Session.create!(user: users(:taha))
    session.update_column(:last_active_at, Session::IDLE_TIMEOUT.ago - 1.minute)
    assert session.expired?
  end

  test "expires after the max lifetime even if recently active" do
    session = Session.create!(user: users(:taha))
    session.update_columns(created_at: Session::MAX_LIFETIME.ago - 1.minute, last_active_at: Time.current)
    assert session.expired?
  end

  test "touch_activity is throttled to avoid a write on every request" do
    session = Session.create!(user: users(:taha))
    recent = 10.minutes.ago
    session.update_column(:last_active_at, recent)

    session.touch_activity
    assert_in_delta recent, session.reload.last_active_at, 1.second, "a recent touch should not be overwritten"

    session.update_column(:last_active_at, 2.hours.ago)
    session.touch_activity
    assert_in_delta Time.current, session.reload.last_active_at, 1.second
  end

  test "cleanup deletes only stale sessions" do
    active = Session.create!(user: users(:taha))
    idle = Session.create!(user: users(:taha))
    idle.update_column(:last_active_at, Session::IDLE_TIMEOUT.ago - 1.minute)

    Session.cleanup
    assert Session.exists?(active.id)
    assert_not Session.exists?(idle.id)
  end
end
