class WaitlistSignupsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, with: -> { redirect_to root_path, alert: "Too many attempts. Try again in a few minutes." }

  def create
    email_address = WaitlistSignup.normalize_value_for(:email_address, params[:email_address])
    unless email_address&.match?(URI::MailTo::EMAIL_REGEXP)
      return redirect_to root_path, alert: "Enter a valid email address."
    end

    _signup, already_joined = WaitlistSignup.join(email_address, source: params[:src].presence)
    flash[:waitlist] = { "email" => email_address, "already_joined" => already_joined }
    redirect_to root_path
  end
end
