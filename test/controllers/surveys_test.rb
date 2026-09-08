require "test_helper"

class SurveysTest < ActionDispatch::IntegrationTest
  setup do
    @definition = current_survey
    @user = users(:taha)
    sign_in_as @user
  end

  def answers_for(hash)
    hash.transform_values { |v| v }
  end

  test "renders the first section with every question card, hidden ones included" do
    get survey_path
    assert_response :success
    first = @definition.sections.first
    assert_select "h1#survey-section-heading", first.title
    assert_select ".question-card", first.questions.length
    assert_select "#survey-stepper button", @definition.sections.length

    get survey_path(s: "hardware")
    assert_select "#qc-apple_experience[hidden]"
    assert_select "#qc-apple_experience[data-show-if-question=machine_types]"
  end

  test "unknown section falls back to the default section" do
    get survey_path(s: "nope")
    assert_response :success
    assert_select "h1#survey-section-heading", @definition.sections.first.title
  end

  test "autosave stores answers and streams progress + inline errors" do
    patch survey_path(s: "setup"), headers: { "Accept" => "text/vnd.turbo-stream.html" }, params: {
      commit: "autosave",
      answers: { "first_linux" => { type: "single", option_id: "yes" }, "install_path" => { type: "single", option_id: "other", other: "" } }
    }
    assert_response :unprocessable_entity
    assert_match "Please specify your answer.", response.body
    assert_equal 0, Answer.count

    patch survey_path(s: "setup"), headers: { "Accept" => "text/vnd.turbo-stream.html" }, params: {
      commit: "autosave",
      answers: { "first_linux" => { type: "single", option_id: "yes" }, "install_path" => { type: "single", option_id: "other", other: "USB" } }
    }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[target=survey-progress]"
    assert_select "turbo-stream[target=survey-section-counts]", /2 of \d+ answered/
    assert_equal 2, Answer.count
  end

  test "next validates required questions, then moves on" do
    patch survey_path(s: "setup"), params: { commit: "next", answers: { "first_linux" => { type: "single", option_id: "yes" } } }
    assert_response :unprocessable_entity
    assert_select "#q-error-daily_driver", "This question is required."
    assert_select "#q-error-install_path", "This question is required."

    patch survey_path(s: "setup"), params: { commit: "next", answers: {
      "first_linux" => { type: "single", option_id: "yes" },
      "daily_driver" => { type: "single", option_id: "only" },
      "install_path" => { type: "single", option_id: "vm" }
    } }
    assert_redirected_to survey_path(s: "hardware")
  end

  test "back and backward jumps never validate; forward jumps do" do
    patch survey_path(s: "hardware"), params: { commit: "back", answers: {} }
    assert_redirected_to survey_path(s: "setup")

    patch survey_path(s: "hardware"), params: { jump_to: "setup", answers: {} }
    assert_redirected_to survey_path(s: "setup")

    patch survey_path(s: "hardware"), params: { jump_to: "you", answers: { "machine_types" => { type: "multiple" } } }
    assert_response :unprocessable_entity

    patch survey_path(s: "hardware"), params: { jump_to: "you", answers: { "machine_types" => { type: "multiple", option_ids: [ "framework" ] } } }
    assert_redirected_to survey_path(s: "you")
  end

  test "submit sends you to the first incomplete section with its errors" do
    patch survey_path(s: "you"), params: { commit: "submit", answers: {} }
    assert_redirected_to survey_path(s: "setup")
    follow_redirect!
    assert_select "#q-error-first_linux", "This question is required."
  end

  test "a complete response submits once and locks" do
    response_record = Response.find_or_start(@definition, @user)
    @definition.questions.select(&:required?).each do |q|
      value = q.type == "multiple" ? { "type" => q.type, "option_ids" => [ q.option_ids.first ] } : { "type" => q.type, "option_id" => q.option_ids.first }
      response_record.save_answers(@definition, { q.id => value })
    end

    patch survey_path(s: "you"), params: { commit: "submit", answers: { "age" => { type: "single", option_id: "a25_34" } } }
    assert_redirected_to done_survey_path
    follow_redirect!
    assert_select "h1", "You're in the record books"
    assert_match(/#{@definition.questions.count(&:required?) + 1} answers now locked in/, response.body)

    get survey_path
    assert_redirected_to done_survey_path
    patch survey_path(s: "you"), params: { commit: "autosave", answers: {} }
    assert_redirected_to done_survey_path

    get done_survey_path
    assert_select "p", /Survey submitted/
  end

  test "done redirects to the survey until submitted" do
    get done_survey_path
    assert_redirected_to survey_path
  end
end
