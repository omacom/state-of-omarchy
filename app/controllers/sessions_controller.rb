class SessionsController < ApplicationController
  require_unauthenticated_access only: :create
  allow_unauthenticated_access only: :destroy
  before_action :require_survey_launched, only: :create
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded

  # Email in -> link + code out. Accounts are created on first request; the address is
  # only trusted once a link or code is verified.
  def create
    email_address = User.normalize_value_for(:email_address, params[:email_address])
    unless email_address&.match?(URI::MailTo::EMAIL_REGEXP)
      return redirect_to root_path, alert: "Enter a valid email address."
    end

    user = User.find_or_create_by!(email_address: email_address)
    redirect_to_session_magic_link user.send_magic_link
  rescue => e
    Rails.logger.error("Failed to send sign-in email: #{e.class}: #{e.message}")
    redirect_to root_path, alert: "Could not send the sign-in email. Please try again."
  end

  def destroy
    terminate_session
    redirect_to root_path
  end

  private
    def rate_limit_exceeded
      redirect_to root_path, alert: "Too many sign-in attempts. Try again in a few minutes."
    end
end
