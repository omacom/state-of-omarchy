require "test_helper"

class WaitlistSignupTest < ActiveSupport::TestCase
  test "join is idempotent and normalizes the address" do
    first, already = WaitlistSignup.join(" Taha@Example.com ", source: "x")
    assert_not already
    assert_equal "taha@example.com", first.email_address
    assert_equal "x", first.source

    second, already = WaitlistSignup.join("taha@example.com")
    assert already
    assert_equal first, second
    assert_equal 1, WaitlistSignup.count
  end

  test "notify_all emails unnotified signups once" do
    WaitlistSignup.join("a@example.com")
    done, _ = WaitlistSignup.join("b@example.com")
    done.update!(notified_at: 1.day.ago)

    assert_emails 1 do
      assert_equal({ sent: 1, failed: 0 }, WaitlistSignup.notify_all)
    end
    assert_equal 0, WaitlistSignup.unnotified.count
    assert_emails 0 do
      WaitlistSignup.notify_all
    end
  end
end
