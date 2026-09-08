# Survey definition core — framework-free pure Ruby.
#
# RULE: nothing in lib/survey/ may depend on Active Record or the request. It is
# used by models, controllers, views, the `survey:lint` task and the test suite alike.
#
# `surveys/<year>/survey.yml` is parsed by Survey::Loader and handed to
# Survey::Parser as a plain Hash. Renderers, validation, storage and progress are
# all derived from question `type` + attributes — never from a specific id.
module Survey
  KNOWN_TYPES = %w[ single multiple scale nps text text_list country ].freeze

  # Reserved option id for a free-text write-in on single/multiple questions with allowOther.
  OTHER_OPTION_ID = "other"

  class ParseError < StandardError; end
  class UnknownEditionError < StandardError; end

  # Raised by Response#save_answers / #submit! with { question_id => message }.
  class InputError < StandardError
    attr_reader :issues

    def initialize(issues)
      @issues = issues
      super("Invalid survey answers")
    end
  end

  def self.known_type?(type)
    KNOWN_TYPES.include?(type.to_s)
  end
end
