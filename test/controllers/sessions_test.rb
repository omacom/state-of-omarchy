require "test_helper"

class SessionsTest < ActionDispatch::IntegrationTest
  test "home shows the sign-in card when launched" do
    get root_path
    assert_response :success
    assert_select "h1", "Shape where Omarchy goes next"
    assert_select "form[action=?]", session_path
  end

  test "requesting a link creates the user, emails link + code and binds the browser" do
    assert_difference [ "User.count", "MagicLink.count" ], 1 do
      assert_emails 1 do
        post session_path, params: { email_address: " New@Example.com " }
      end
    end
    assert_redirected_to session_magic_link_path
    assert cookies[:pending_authentication_token].present?

    follow_redirect!
    assert_select "p", /new@example.com/
    assert_select "form[action=?]", session_magic_link_path
  end

  test "an invalid email is bounced back with an alert" do
    post session_path, params: { email_address: "nope" }
    assert_redirected_to root_path
    follow_redirect!
    assert_select "p[role=alert]", "Enter a valid email address."
  end

  test "signing in with the code starts a session and lands on the survey" do
    user = users(:taha)
    post session_path, params: { email_address: user.email_address }
    code = user.magic_links.last.code

    post session_magic_link_path, params: { code: code.downcase }
    assert_redirected_to survey_path
    assert cookies[:session_id].present?
    assert_equal 0, user.magic_links.count, "the link is consumed"
    assert_empty cookies[:pending_authentication_token].to_s

    get survey_path
    assert_response :success
  end

  test "a code from another user's link is rejected" do
    post session_path, params: { email_address: users(:taha).email_address }
    other_link = MagicLink.create!(user: users(:other))

    post session_magic_link_path, params: { code: other_link.code }
    assert_redirected_to root_path
    assert_empty cookies[:session_id].to_s
  end

  test "a wrong code stays on the inbox page with an alert" do
    post session_path, params: { email_address: users(:taha).email_address }
    post session_magic_link_path, params: { code: "ZZZZZZ" }
    assert_redirected_to session_magic_link_path
    follow_redirect!
    assert_select "p[role=alert]", /didn’t work/
  end

  test "the code page needs a pending request" do
    get session_magic_link_path
    assert_redirected_to root_path
  end

  test "the emailed link signs in from a fresh browser and is single use" do
    user = users(:taha)
    magic_link = user.send_magic_link

    get verify_magic_link_path(magic_link.token)
    assert_response :success
    assert_select "input[name=token][value=?]", magic_link.token

    post session_magic_link_path, params: { token: magic_link.token }
    assert_redirected_to survey_path
    assert cookies[:session_id].present?

    sign_out
    post session_magic_link_path, params: { token: magic_link.token }
    assert_redirected_to auth_error_path(error: "INVALID_TOKEN")
    follow_redirect!
    assert_select "h1", /already been used/
  end

  test "signed-in users skip the home page and can sign out" do
    sign_in_as users(:taha)
    get root_path
    assert_redirected_to survey_path

    delete session_path
    assert_redirected_to root_path
    get survey_path
    assert_redirected_to root_path
  end

  test "return path is remembered across sign in" do
    get survey_path(s: "themes")
    assert_redirected_to root_path
    sign_in_as users(:taha)
    assert_redirected_to survey_path(s: "themes")
  end

  test "an idle-expired session is logged out and its cookie cleared" do
    sign_in_as users(:taha)
    session = users(:taha).sessions.last
    session.update_column(:last_active_at, Session::IDLE_TIMEOUT.ago - 1.minute)

    get survey_path
    assert_redirected_to root_path
    assert_empty cookies[:session_id].to_s
    assert_not Session.exists?(session.id)
  end

  test "before launch the sign-in endpoints are closed and home shows the waitlist" do
    with_survey_launched(false) do
      get root_path
      assert_select "h1", "Don't miss the survey"
      post session_path, params: { email_address: users(:taha).email_address }
      assert_redirected_to root_path
      get survey_path
      assert_redirected_to root_path
    end
  end
end
