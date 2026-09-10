ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    include ActionMailer::TestHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Rate limiting counters live in Rails.cache; clear it so one test's requests
    # never count against another test's rate limit in the same worker process.
    setup { Rails.cache.clear }

    def current_survey
      Survey::Loader.load(Rails.configuration.x.survey.current_edition)
    end

    # A tiny hand-built definition for engine tests, so they never depend on the real yml.
    def build_definition(sections)
      Survey::Parser.parse({
        "survey" => { "id" => "t", "editionId" => "test", "year" => 2026, "title" => "Test", "version" => 1 },
        "sections" => sections
      })
    end
  end
end

module SessionTestHelper
  # Drives the real sign-in flow: request a link, then post the code it minted.
  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address }
    magic_link = user.magic_links.order(:id).last
    post session_magic_link_path, params: { code: magic_link.code }
    assert_response :redirect
    assert cookies[:session_id].present?, "Expected a session cookie after sign in"
  end

  def sign_out
    delete session_path
  end

  def with_survey_launched(launched)
    previous = Rails.configuration.x.survey.launched
    Rails.configuration.x.survey.launched = launched
    yield
  ensure
    Rails.configuration.x.survey.launched = previous
  end
end

class ActionDispatch::IntegrationTest
  include SessionTestHelper
end
