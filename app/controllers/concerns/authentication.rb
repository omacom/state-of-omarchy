# Cookie sessions on top of a Session row, after Fizzy / the Rails 8 authentication
# generator. Every controller requires a session unless it opts out with
# `allow_unauthenticated_access`; `require_unauthenticated_access` additionally
# bounces signed-in users to the survey.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_user

    include Authentication::ViaMagicLink
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :resume_session, **options
    end

    def require_unauthenticated_access(**options)
      allow_unauthenticated_access(**options)
      before_action :redirect_authenticated_user, **options
    end
  end

  private
    def authenticated?
      Current.session.present?
    end

    def current_user
      Current.user
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.fullpath if request.get? || request.head?
      redirect_to root_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || survey_path
    end

    def redirect_authenticated_user
      redirect_to after_authentication_url if authenticated?
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(:session_id)
    end
end
