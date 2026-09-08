require "test_helper"

class MagicLinkTest < ActiveSupport::TestCase
  test "new links get a code, a token and an expiry" do
    magic_link = MagicLink.create!(user: users(:taha))
    assert_equal MagicLink::CODE_LENGTH, magic_link.code.length
    assert magic_link.token.present?
    assert_in_delta MagicLink::EXPIRATION_TIME.from_now, magic_link.expires_at, 1.second
  end

  test "consume by code tolerates spaces, lowercase and look-alike digits" do
    magic_link = MagicLink.create!(user: users(:taha))
    typed = magic_link.code.downcase.tr("OIL", "011").chars.join(" ")
    assert_equal magic_link, MagicLink.consume_code(typed)
    assert_not MagicLink.exists?(magic_link.id)
    assert_nil MagicLink.consume_code(magic_link.code), "consumed codes are single use"
    assert_nil MagicLink.consume_code(nil)
    assert_nil MagicLink.consume_code("   ")
  end

  test "consume by token is single use and ignores expired links" do
    magic_link = MagicLink.create!(user: users(:taha))
    assert_equal magic_link, MagicLink.consume_token(magic_link.token)
    assert_nil MagicLink.consume_token(magic_link.token)

    expired = MagicLink.create!(user: users(:taha))
    expired.update_column(:expires_at, 1.hour.ago)
    assert_nil MagicLink.consume_token(expired.token)
    assert_nil MagicLink.consume_code(expired.code)
    assert MagicLink.exists?(expired.id)
  end

  test "cleanup deletes only stale links" do
    active = MagicLink.create!(user: users(:taha))
    stale = MagicLink.create!(user: users(:taha))
    stale.update_column(:expires_at, 1.minute.ago)
    MagicLink.cleanup
    assert MagicLink.exists?(active.id)
    assert_not MagicLink.exists?(stale.id)
  end

  test "sending a magic link delivers one email with link and code" do
    user = users(:taha)
    assert_emails 1 do
      magic_link = user.send_magic_link
      mail = ActionMailer::Base.deliveries.last
      assert_equal [ user.email_address ], mail.to
      assert_includes mail.text_part.body.to_s, magic_link.code
      assert_includes mail.text_part.body.to_s, "/session/magic_link/#{magic_link.token}"
    end
  end
end
