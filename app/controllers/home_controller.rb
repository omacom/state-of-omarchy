class HomeController < ApplicationController
  allow_unauthenticated_access

  # Before launch: waitlist. After launch: sign-in card, or straight to the survey.
  def show
    if survey_launched? && authenticated?
      redirect_to after_authentication_url
    end
  end
end
