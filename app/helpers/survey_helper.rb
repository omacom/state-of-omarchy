module SurveyHelper
  # Form field name for one attribute of a question's answer, e.g. answers[gpu][option_id].
  def answer_field(question, attr, array: false)
    "answers[#{question.id}][#{attr}]#{'[]' if array}"
  end

  # Partial that renders a question's input — keyed ONLY by type. Unknown types fall
  # back to a graceful notice instead of crashing.
  def question_input_partial(question)
    Survey.known_type?(question.type) ? "surveys/questions/#{question.type}" : "surveys/questions/unsupported"
  end

  # showIf as data attributes so the client can toggle visibility for targets that live
  # in the same section; cross-section targets are resolved server-side at render time.
  def show_if_data(question)
    return {} unless (s = question.show_if)
    { show_if_question: s.question_id, show_if_op: s.op, show_if_values: s.values.to_json }
  end

  def nps_band(value)
    return nil unless value.is_a?(Integer)
    value <= 6 ? "Detractor" : (value <= 8 ? "Passive" : "Promoter")
  end
end
