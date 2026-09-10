require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "typing a complete code submits the form automatically" do
    user = users(:taha)

    visit root_path
    fill_in "email_address", with: user.email_address
    click_button "Send sign-in email"
    assert_text "Check your inbox"

    magic_link = user.magic_links.order(:id).last
    fill_in "code", with: magic_link.code

    assert_selector "#survey-section-heading"
  end

  test "the code button stays disabled until a full code is entered" do
    user = users(:taha)

    visit root_path
    fill_in "email_address", with: user.email_address
    click_button "Send sign-in email"
    assert_text "Check your inbox"

    assert_button "Sign in with code", disabled: true
    fill_in "code", with: "ABC"
    assert_button "Sign in with code", disabled: true
  end

  test "the resend button is disabled during the cooldown and re-enables after it" do
    original_cooldown = MagicLink.resend_cooldown
    MagicLink.resend_cooldown = 5.seconds

    user = users(:taha)

    visit root_path
    fill_in "email_address", with: user.email_address
    click_button "Send sign-in email"
    assert_text "Check your inbox"

    # The button's label ticks down ("Send again in 5s"...) as soon as it connects,
    # so it's found by its data attribute rather than by transient text.
    assert_selector "button[data-cooldown-target='button'][disabled]"
    assert_selector "button[data-cooldown-target='button']:not([disabled])", wait: 6
  ensure
    MagicLink.resend_cooldown = original_cooldown
  end
end
