class WaitlistMailer < ApplicationMailer
  def launch(signup)
    @url = root_url
    @survey = Survey::Loader.load(Rails.configuration.x.survey.current_edition)

    mail to: signup.email_address, subject: "The #{@survey.title} #{@survey.year} survey is live"
  end
end
