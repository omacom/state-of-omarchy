# Preview all emails at http://localhost:3000/rails/mailers/magic_link_mailer
class MagicLinkMailerPreview < ActionMailer::Preview
  def sign_in_instructions
    user = User.new(email_address: "you@example.com")
    magic_link = MagicLink.new(user: user, code: "A2B3C4", token: "preview-token", expires_at: MagicLink::EXPIRATION_TIME.from_now)
    MagicLinkMailer.sign_in_instructions(magic_link)
  end
end
