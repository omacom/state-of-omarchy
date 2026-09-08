require "test_helper"

class ResponseTest < ActiveSupport::TestCase
  setup do
    @definition = current_survey
    @response = Response.find_or_start(@definition, users(:taha), source: "discord")
  end

  test "find_or_start is idempotent per user and edition" do
    again = Response.find_or_start(@definition, users(:taha))
    assert_equal @response, again
    assert_equal "discord", again.source
    assert_equal @definition.version, again.survey_version
  end

  test "save_answers writes normalized rows and reports completion" do
    completion = @response.save_answers(@definition, {
      "first_linux" => { "type" => "single", "option_id" => "yes" },
      "previous_os" => { "type" => "multiple", "option_ids" => [ "macos", "other" ], "other" => " Haiku " },
      "favorite_themes" => { "type" => "text_list", "items" => [ "Nord", "", " Gruvbox " ] },
      "theme_sync" => { "type" => "scale", "value" => "4" },
      "country" => { "type" => "country", "code" => "tr" },
      "testimonial" => { "type" => "text", "text" => "  Love it  " },
      "ghost_question" => { "type" => "text", "text" => "dropped" }
    }, enforce_required: false)

    assert completion.positive?
    values = @response.values(@definition)
    assert_equal Survey::Value.single("yes"), values["first_linux"]
    assert_equal Survey::Value.multiple([ "macos", "other" ], other: "Haiku"), values["previous_os"]
    assert_equal Survey::Value.list([ "Nord", "Gruvbox" ]), values["favorite_themes"]
    assert_equal Survey::Value.number(4), values["theme_sync"]
    assert_equal Survey::Value.country("tr"), values["country"]
    assert_equal Survey::Value.text("Love it"), values["testimonial"]
    assert_nil values["ghost_question"]
    assert_equal [ 0, 1 ], @response.answers.where(question_id: "favorite_themes").order(:position).pluck(:position)
  end

  test "save_answers is all-or-nothing and raises with per-question issues" do
    error = assert_raises(Survey::InputError) do
      @response.save_answers(@definition, {
        "first_linux" => { "type" => "single", "option_id" => "yes" },
        "install_path" => { "type" => "single", "option_id" => "other", "other" => "" }
      }, enforce_required: false)
    end
    assert_equal({ "install_path" => "Please specify your answer." }, error.issues)
    assert_equal 0, @response.answers.count
  end

  test "hidden questions are cleared when their showIf target changes" do
    @response.save_answers(@definition, {
      "uses_local_models" => { "type" => "single", "option_id" => "yes" },
      "local_llm" => { "type" => "multiple", "option_ids" => [ "ollama" ] }
    }, enforce_required: false)
    assert_equal 1, @response.answers.where(question_id: "local_llm").count

    @response.save_answers(@definition, { "uses_local_models" => { "type" => "single", "option_id" => "no" } }, enforce_required: false)
    assert_equal 0, @response.answers.where(question_id: "local_llm").count
  end

  test "submit! requires every visible required question" do
    error = assert_raises(Survey::InputError) { @response.submit! @definition }
    required = @definition.questions.select(&:required?).map(&:id)
    assert_equal required.sort, error.issues.keys.sort
    assert_not @response.reload.submitted?

    required.each do |qid|
      q = @definition.question(qid)
      value = q.type == "multiple" ? { "type" => q.type, "option_ids" => [ q.option_ids.first ] } : { "type" => q.type, "option_id" => q.option_ids.first }
      @response.save_answers(@definition, { qid => value })
    end
    @response.submit! @definition
    assert @response.reload.submitted?
    assert_equal 100, @response.completion
    assert_raises(RuntimeError) { @response.save_answers(@definition, {}) }
  end

  test "one response per user per edition" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Response.create!(edition_id: @definition.edition_id, survey_version: 1, user: users(:taha))
    end
  end
end
