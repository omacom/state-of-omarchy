class Answer < ApplicationRecord
  belongs_to :response

  # Rebuild { question_id => Survey::Value } from stored rows. Unknown-type questions
  # (and ids no longer in the yml) are skipped, never raised on.
  def self.to_values(definition, rows)
    rows.group_by(&:question_id).each_with_object({}) do |(qid, qrows), out|
      question = definition.question(qid)
      next unless question&.known?

      case question.type
      when "single"
        row = qrows.first
        out[qid] = Survey::Value.single(row.option_id, other: row.text_value) if row&.option_id.present?
      when "multiple"
        ids = qrows.map(&:option_id).compact_blank
        other = qrows.find { |r| r.option_id == Survey::OTHER_OPTION_ID }&.text_value
        out[qid] = Survey::Value.multiple(ids, other: other) if ids.any?
      when "scale", "nps"
        v = qrows.first&.number_value
        out[qid] = Survey::Value.number(v) if v.is_a?(Integer)
      when "text"
        t = qrows.first&.text_value
        out[qid] = Survey::Value.text(t) if t.present?
      when "text_list"
        items = qrows.sort_by { |r| r.position.to_i }.map(&:text_value).compact_blank
        out[qid] = Survey::Value.list(items) if items.any?
      when "country"
        code = qrows.first&.option_id
        out[qid] = Survey::Value.country(code) if code.present?
      end
    end
  end

  # Map a validated Survey::Value to row attributes (response attached by caller).
  def self.rows_for(question, value)
    return [] unless question.known?
    case value.kind
    when "single"
      return [] if value.option_id.blank?
      [ { question_id: question.id, option_id: value.option_id, text_value: value.other_text } ]
    when "multiple"
      value.option_ids.map do |id|
        { question_id: question.id, option_id: id,
          text_value: (id == Survey::OTHER_OPTION_ID ? value.other_text : nil) }
      end
    when "number"
      [ { question_id: question.id, number_value: value.value } ]
    when "text"
      t = value.text.to_s.strip
      t.empty? ? [] : [ { question_id: question.id, text_value: t } ]
    when "list"
      value.items.map(&:strip).reject(&:empty?).each_with_index.map do |text, position|
        { question_id: question.id, text_value: text, position: position }
      end
    when "country"
      value.code.blank? ? [] : [ { question_id: question.id, option_id: value.code } ]
    else
      []
    end
  end
end
