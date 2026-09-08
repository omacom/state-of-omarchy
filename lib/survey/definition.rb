module Survey
  # A parsed survey edition plus every generic rule derived from it: visibility,
  # answered-ness, validation and progress. `answers` everywhere below is a
  # Hash { question_id => Survey::Value }.
  class Definition
    attr_reader :id, :edition_id, :year, :title, :hashtag, :estimated_minutes, :version, :sections

    def initialize(id:, edition_id:, year:, title:, version:, sections:, hashtag: nil, estimated_minutes: nil)
      @id = id
      @edition_id = edition_id
      @year = year
      @title = title
      @hashtag = hashtag
      @estimated_minutes = estimated_minutes
      @version = version
      @sections = sections
    end

    # ---------------------------------------------------------------- lookup

    def questions
      @questions ||= sections.flat_map(&:questions)
    end

    def question(id)
      questions_by_id[id.to_s]
    end

    def section(id)
      sections.find { |s| s.id == id.to_s }
    end

    def section_of(question_id)
      sections.find { |s| s.questions.any? { |q| q.id == question_id.to_s } }
    end

    def section_index(section)
      sections.index(section)
    end

    # ------------------------------------------------------------ visibility

    # Generic showIf evaluator. `eq` matches a single-valued answer; `includesAny`
    # matches when any selected id is in values. Missing/empty target answer hides.
    def visible?(question, answers)
      show_if = question.show_if
      return true unless show_if
      ids = (answers[show_if.question_id] || Value.empty).ids
      return false if ids.empty?
      if show_if.op == "eq"
        ids.length == 1 && show_if.values.include?(ids.first)
      else
        ids.any? { |id| show_if.values.include?(id) }
      end
    end

    # Includes unknown types on purpose — renderers show the graceful fallback.
    def visible_questions(section, answers)
      section.questions.select { |q| visible?(q, answers) }
    end

    # -------------------------------------------------------- answered/valid

    def answered?(question, value)
      return false if value.nil? || value.empty? || !question.known?
      case value.kind
      when "single" then value.option_id.present?
      when "multiple" then value.option_ids.any?
      when "number" then value.value.is_a?(Integer)
      when "text" then !value.text.to_s.strip.empty?
      when "list" then value.items.any? { |i| !i.strip.empty? }
      when "country" then value.code.present?
      else false
      end
    end

    # Validate one answer. Returns an error message or nil. Assumes the question is
    # visible — callers skip hidden questions entirely. Never raises on yml content.
    # `enforce_required: false` skips only the emptiness check (used by autosave).
    def validate(question, value, enforce_required: true)
      return nil unless question.known?
      unless answered?(question, value)
        return (question.required? && enforce_required) ? "This question is required." : nil
      end

      case question.type
      when "single"
        return "Invalid answer." unless value.kind == "single"
        listed = question.option_ids.include?(value.option_id)
        other = value.option_id == OTHER_OPTION_ID
        return "Please choose a valid option." unless listed || (other && question.allow_other?)
        return "Please specify your answer." if other && question.allow_other? && value.other_text.nil?
        nil
      when "multiple"
        return "Invalid answer." unless value.kind == "multiple"
        value.option_ids.each do |id|
          listed = question.option_ids.include?(id)
          other = id == OTHER_OPTION_ID
          return "Please choose valid options." unless listed || (other && question.allow_other?)
          return "Please specify your “Other” answer." if other && question.allow_other? && value.other_text.nil?
        end
        return "Select at most #{question.limit}." if question.limit && value.option_ids.length > question.limit
        picked_exclusive = value.option_ids & question.exclusive_options
        if picked_exclusive.any? && value.option_ids.length > picked_exclusive.length
          return "“#{question.option_label(picked_exclusive.first)}” can’t be combined with other options."
        end
        nil
      when "scale", "nps"
        return "Invalid answer." unless value.kind == "number"
        v = value.value
        unless v.is_a?(Integer) && v >= question.min && v <= question.max
          return "Please pick a value between #{question.min} and #{question.max}."
        end
        nil
      when "text"
        return "Invalid answer." unless value.kind == "text"
        return "Keep it under #{question.max_length} characters." if question.max_length && value.text.length > question.max_length
        nil
      when "text_list"
        return "Invalid answer." unless value.kind == "list"
        items = value.items.map(&:strip).reject(&:empty?)
        return "At most #{question.limit} entries." if question.limit && items.length > question.limit
        nil
      when "country"
        return "Invalid answer." unless value.kind == "country"
        nil
      end
    end

    # -------------------------------------------------------------- progress

    # Answered share (0–100) of all visible, known questions.
    def completion(answers)
      visible = questions.select { |q| q.known? && visible?(q, answers) }
      return 100 if visible.empty?
      answered = visible.count { |q| answered?(q, answers[q.id]) }
      (answered * 100.0 / visible.length).round
    end

    # A section is complete when all its visible, known, required questions are answered.
    def section_complete?(section, answers)
      section.questions
        .select { |q| q.known? && q.required? && visible?(q, answers) }
        .all? { |q| answered?(q, answers[q.id]) }
    end

    # { answered:, total: } over a section's visible known questions (optional ones too).
    def section_counts(section, answers)
      visible = section.questions.select { |q| q.known? && visible?(q, answers) }
      { answered: visible.count { |q| answered?(q, answers[q.id]) }, total: visible.length }
    end

    def section_completion(section, answers)
      counts = section_counts(section, answers)
      return 100 if counts[:total].zero?
      (counts[:answered] * 100.0 / counts[:total]).round
    end

    def completed_section_count(answers)
      sections.count { |s| section_complete?(s, answers) }
    end

    # Default step: first section with unanswered required, else any unanswered, else first.
    def default_section(answers)
      sections.find { |s| !section_complete?(s, answers) } ||
        sections.find { |s| c = section_counts(s, answers); c[:answered] < c[:total] } ||
        sections.first
    end

    private
      # First definition wins on a duplicate id (lint reports the duplicate).
      def questions_by_id
        @questions_by_id ||= questions.each_with_object({}) { |q, h| h[q.id] ||= q }
      end
  end
end
