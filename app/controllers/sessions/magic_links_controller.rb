class Sessions::MagicLinksController < ApplicationController
  require_unauthenticated_access
  before_action :require_survey_launched
  before_action :ensure_that_email_address_pending_authentication_exists, only: [ :show, :create ]
  rate_limit to: 10, within: 15.minutes, only: :create, with: :rate_limit_exceeded

  # "Check your inbox": code entry + resend + change email.
  def show
  end

  # From the emailed link. Renders a form that submits the token (auto-submitted with JS)
  # so a link prefetch by a mail scanner never consumes it.
  def verify
    @token = params[:token]
  end

  def create
    if params[:token].present?
      authenticate_with_token
    else
      authenticate_with_code
    end
  end

  # "Use a different email"
  def destroy
    clear_pending_authentication_token
    redirect_to root_path
  end

  # Landing page for invalid/expired links (mirrors the old /auth/error route).
  def error
    @reason = params[:error]
  end

  private
    # The emailed link carries its own long token and needs no browser binding.
    def ensure_that_email_address_pending_authentication_exists
      return if params[:token].present?
      unless email_address_pending_authentication.present?
        redirect_to root_path, alert: "Enter your email address to sign in."
      end
    end

    def authenticate_with_code
      magic_link = MagicLink.consume_code(params[:code])
      if magic_link.nil?
        redirect_to session_magic_link_path, alert: "That code didn’t work. Try again, or use the link in the email."
      elsif ActiveSupport::SecurityUtils.secure_compare(email_address_pending_authentication.to_s, magic_link.user.email_address)
        sign_in magic_link
      else
        clear_pending_authentication_token
        redirect_to root_path, alert: "Something went wrong. Please try again."
      end
    end

    def authenticate_with_token
      if magic_link = MagicLink.consume_token(params[:token])
        sign_in magic_link
      else
        redirect_to auth_error_path(error: "INVALID_TOKEN")
      end
    end

    def sign_in(magic_link)
      clear_pending_authentication_token
      start_new_session_for magic_link.user
      redirect_to after_authentication_url
    end

    def rate_limit_exceeded
      redirect_to session_magic_link_path, alert: "Too many attempts. Try again in 15 minutes."
    end
end
