# The typed code only works in the browser that asked for it: requesting a link sets a
# short-lived signed cookie carrying the email address, and the code is accepted only
# when it belongs to that same address. The emailed link (long token) has no such
# binding so it works from any device.
module Authentication::ViaMagicLink
  extend ActiveSupport::Concern

  included do
    helper_method :email_address_pending_authentication
    after_action :ensure_development_magic_link_not_leaked
  end

  private
    def ensure_development_magic_link_not_leaked
      unless Rails.env.development?
        raise "Leaking magic link via flash in #{Rails.env}?" if flash[:magic_link_code].present?
      end
    end

    def redirect_to_session_magic_link(magic_link)
      serve_development_magic_link(magic_link)
      set_pending_authentication_token(magic_link)
      redirect_to session_magic_link_path
    end

    # In development the mail isn't delivered, so surface link + code on the page
    # (and in a response header) the way Fizzy does.
    def serve_development_magic_link(magic_link)
      if Rails.env.development? && magic_link.present?
        flash[:magic_link_code] = magic_link.code
        flash[:magic_link_url] = verify_magic_link_url(magic_link.token)
        response.set_header("X-Magic-Link-Code", magic_link.code)
      end
    end

    def set_pending_authentication_token(magic_link)
      cookies[:pending_authentication_token] = {
        value: pending_authentication_token_verifier.generate(magic_link.user.email_address, expires_at: magic_link.expires_at),
        httponly: true,
        same_site: :lax,
        expires: magic_link.expires_at
      }
    end

    def email_address_pending_authentication
      pending_authentication_token_verifier.verified(cookies[:pending_authentication_token])
    end

    def pending_authentication_token_verifier
      Rails.application.message_verifier(:pending_authentication)
    end

    def clear_pending_authentication_token
      cookies.delete(:pending_authentication_token)
    end
end
