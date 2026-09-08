# Preview all emails at http://localhost:3000/rails/mailers/waitlist_mailer
class WaitlistMailerPreview < ActionMailer::Preview
  def launch
    WaitlistMailer.launch(WaitlistSignup.new(email_address: "you@example.com"))
  end
end
