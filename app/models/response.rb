class Response < ApplicationRecord
  belongs_to :user
  has_many :answers, dependent: :delete_all

  scope :submitted, -> { where.not(submitted_at: nil) }
  scope :for_edition, ->(edition_id) { where(edition_id: edition_id) }

  before_validation { self.started_at ||= Time.current }

  def self.find_or_start(definition, user, source: nil, user_agent: nil, locale: nil)
    create_or_find_by!(edition_id: definition.edition_id, user_id: user.id) do |r|
      r.survey_version = definition.version
      r.source = source
      r.user_agent = user_agent&.truncate(255)
      r.locale = locale
    end
  end

  def submitted?
    submitted_at.present?
  end

  # { question_id => Survey::Value } for every stored answer.
  def values(definition)
    Answer.to_values(definition, answers.to_a)
  end

  # Save one step's answers from untrusted params: coerce + validate against the yml
  # (using the merged full answer set for showIf), then delete-then-insert per question
  # in a transaction. Hidden questions are cleared. Returns fresh completion %.
  # Raises Survey::InputError on any issue (nothing is written).
  def save_answers(definition, raw_input, enforce_required: true)
    raise "Response already submitted" if submitted?

    merged = values(definition)
    issues = {}
    accepted = {}

    raw_input.to_h.each do |qid, raw|
      question = definition.question(qid)
      next unless question&.known? # unknown ids/types: dropped silently
      value = Survey::Value.from_params(question, raw)
      merged[question.id] = value
      accepted[question.id] = value
    end

    accepted.each do |qid, value|
      question = definition.question(qid)
      unless definition.visible?(question, merged)
        accepted[qid] = Survey::Value.empty # hidden: clear stored answers
        next
      end
      problem = definition.validate(question, value, enforce_required: enforce_required)
      issues[qid] = problem if problem
    end

    raise Survey::InputError.new(issues) if issues.any?

    transaction do
      accepted.each do |qid, value|
        question = definition.question(qid)
        answers.where(question_id: qid).delete_all
        rows = Answer.rows_for(question, value)
        answers.insert_all(rows) if rows.any?
      end
      # Anything that just became hidden through a changed showIf target goes too.
      prune_hidden!(definition, values(definition))
      update!(completion: definition.completion(values(definition)))
    end
    completion
  end

  # Final submit: validates ALL required visible questions across ALL sections.
  # Raises Survey::InputError listing every problem (keyed by question id).
  def submit!(definition)
    return if submitted? # idempotent
    current = values(definition)
    issues = {}
    definition.questions.each do |q|
      next unless q.known? && definition.visible?(q, current)
      problem = definition.validate(q, current[q.id])
      issues[q.id] = problem if problem
    end
    prune_hidden!(definition, current)
    raise Survey::InputError.new(issues) if issues.any?
    update!(submitted_at: Time.current, completion: 100)
  end

  private
    # Drop answers to questions that are no longer visible given the other answers.
    def prune_hidden!(definition, current)
      definition.questions.each do |q|
        if definition.answered?(q, current[q.id]) && !definition.visible?(q, current)
          answers.where(question_id: q.id).delete_all
        end
      end
    end
end
