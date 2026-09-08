require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Soo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "UTC"

    # ---- App settings (all overridable through the environment; see .env.example) ----

    # The edition served at /survey. Bump for 2027+ once surveys/2027/survey.yml exists.
    config.x.survey.current_edition = ENV.fetch("SURVEY_EDITION", "2026")

    # Launch toggle: false/unset shows the email-only waitlist on "/" and blocks /survey.
    # Development and test default to launched so the survey itself is reachable while working on it.
    config.x.survey.launched = ENV.fetch("SURVEY_LAUNCHED") { Rails.env.local? ? "true" : "false" } == "true"

    # Public origin, used for absolute URLs in emails and social tags.
    config.x.app_host = ENV.fetch("APP_HOST", "localhost:3000")
    config.x.app_protocol = ENV.fetch("APP_PROTOCOL") { Rails.env.production? ? "https" : "http" }

    config.x.mailer_from = ENV.fetch("MAILER_FROM", "State of Omarchy <survey@omarchy.org>")

    config.action_mailer.default_url_options = { host: config.x.app_host, protocol: config.x.app_protocol }
  end
end
