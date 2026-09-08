# One page per section. Answers are autosaved (PATCH with commit=autosave, answered by a
# Turbo Stream that refreshes progress + inline errors) and every nav button is a normal
# form submit so the flow works without JavaScript too.
class SurveysController < ApplicationController
  before_action :require_survey_launched
  before_action :set_response
  before_action :redirect_if_submitted, except: :done

  def show
    @answers = @response.values(current_survey)
    @section = requested_section || current_survey.default_section(@answers)
    @errors = flash[:survey_issues] || {}
    @stale = true if flash[:survey_stale]
  end

  def update
    @section = requested_section || current_survey.sections.first
    # Stepper pills submit `jump_to=<section id>`; every other button carries `commit`.
    target = params[:jump_to].presence
    commit = target ? "jump" : params[:commit].to_s
    enforce = %w[next submit].include?(commit) || (commit == "jump" && forward_jump?(target))

    issues = save_section(enforce_required: enforce)
    # Moving forward also requires every visible required question of the section to be
    # answered — including ones the payload left out.
    issues = section_issues if issues.empty? && enforce

    case commit
    when "autosave"
      @answers = @response.values(current_survey)
      @errors = issues
      render :autosave, status: (issues.any? ? :unprocessable_entity : :ok), formats: :turbo_stream
    when "back"
      redirect_to survey_path(s: neighbour_section(-1).id)
    when "jump"
      if issues.any? && enforce
        render_errors(issues)
      else
        redirect_to survey_path(s: (current_survey.section(target) || @section).id)
      end
    when "submit"
      issues.any? ? render_errors(issues) : submit_response
    else # "next"
      issues.any? ? render_errors(issues) : redirect_to(survey_path(s: neighbour_section(1).id))
    end
  end

  # Kept as a standalone endpoint so the confirm dialog (and tests) can submit without a
  # section form; the footer button goes through #update with commit=submit instead.
  def submit
    submit_response
  end

  def done
    unless @response&.submitted?
      return redirect_to survey_path
    end
    @answers = @response.values(current_survey)
    @answered = @answers.count { |qid, v| (q = current_survey.question(qid)) && current_survey.answered?(q, v) }
    @completion = current_survey.completion(@answers)
  end

  private
    def set_response
      @response = Response.find_or_start(
        current_survey, Current.user,
        source: params[:src].presence,
        user_agent: request.user_agent,
        locale: request.headers["Accept-Language"]&.split(",")&.first
      )
    end

    def redirect_if_submitted
      redirect_to done_survey_path if @response.submitted?
    end

    def requested_section
      current_survey.section(params[:s]) if params[:s].present?
    end

    def section_index
      current_survey.section_index(@section)
    end

    def neighbour_section(delta)
      current_survey.sections[(section_index + delta).clamp(0, current_survey.sections.length - 1)]
    end

    def forward_jump?(target_id)
      target = current_survey.section(target_id)
      target && current_survey.section_index(target) > section_index
    end

    def answer_params
      params.fetch(:answers, {}).to_unsafe_h
    end

    # Returns { question_id => message }; empty on success.
    def save_section(enforce_required:)
      @response.save_answers(current_survey, answer_params, enforce_required: enforce_required)
      {}
    rescue Survey::InputError => e
      e.issues
    end

    def section_issues
      answers = @response.values(current_survey)
      current_survey.visible_questions(@section, answers).each_with_object({}) do |question, issues|
        problem = current_survey.validate(question, answers[question.id])
        issues[question.id] = problem if problem
      end
    end

    def render_errors(issues)
      @answers = @response.values(current_survey).merge(current_section_values)
      @errors = issues
      render :show, status: :unprocessable_entity
    end

    # Re-render what the user just typed (even if invalid) rather than the last saved state.
    def current_section_values
      answer_params.each_with_object({}) do |(qid, raw), out|
        question = current_survey.question(qid)
        out[qid] = Survey::Value.from_params(question, raw) if question
      end
    end

    def submit_response
      @response.submit!(current_survey)
      redirect_to done_survey_path
    rescue Survey::InputError => e
      owner = current_survey.section_of(e.issues.keys.first)
      if @section && owner == @section
        render_errors(e.issues)
      else
        flash[:survey_issues] = e.issues
        redirect_to survey_path(s: owner&.id)
      end
    end
end
