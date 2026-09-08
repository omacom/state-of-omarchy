class ApplicationController < ActionController::Base
  include Authentication
  include SurveyContext

  helper_method :survey_launched?
end
