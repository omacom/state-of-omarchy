# Access to the current survey edition, the launch toggle, and the signed-in user's
# response status (shown in the header on every page).
module SurveyContext
  extend ActiveSupport::Concern

  included do
    helper_method :current_survey, :survey_status
  end

  private
    def current_survey
      @current_survey ||= Survey::Loader.load(Rails.configuration.x.survey.current_edition)
    end

    def survey_launched?
      Rails.configuration.x.survey.launched
    end

    # Before launch, every /survey* route sends people home regardless of session.
    def require_survey_launched
      redirect_to root_path unless survey_launched?
    end

    def find_response
      Response.for_edition(current_survey.edition_id).find_by(user_id: Current.user.id) if authenticated?
    end

    # nil when the user hasn't started this edition. Memoized per request.
    def survey_status
      return @survey_status if defined?(@survey_status)
      response = find_response
      @survey_status = response && { submitted: response.submitted?, completion: response.completion }
    end
end
