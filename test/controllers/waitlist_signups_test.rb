require "test_helper"

class WaitlistSignupsTest < ActionDispatch::IntegrationTest
  test "joining shows the confirmation and is idempotent" do
    with_survey_launched(false) do
      assert_difference "WaitlistSignup.count", 1 do
        post waitlist_signup_path(src: "discord"), params: { email_address: "Fan@Example.com" }
      end
      assert_redirected_to root_path
      follow_redirect!
      assert_select "p", "You're on the list"
      assert_select "span", "fan@example.com"
      assert_equal "discord", WaitlistSignup.last.source

      post waitlist_signup_path, params: { email_address: "fan@example.com" }
      follow_redirect!
      assert_select "p", "You're already on the list"
    end
  end

  test "rejects an invalid address" do
    with_survey_launched(false) do
      post waitlist_signup_path, params: { email_address: "nope" }
      follow_redirect!
      assert_select "p[role=alert]", "Enter a valid email address."
    end
  end
end
