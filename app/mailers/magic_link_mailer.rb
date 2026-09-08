class MagicLinkMailer < ApplicationMailer
  def sign_in_instructions(magic_link)
    @magic_link = magic_link
    @url = verify_magic_link_url(magic_link.token)
    @survey = Survey::Loader.load(Rails.configuration.x.survey.current_edition)

    mail to: magic_link.user.email_address, subject: "Sign in to #{@survey.title} #{@survey.year}"
  end
end
