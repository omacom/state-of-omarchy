module Survey
  # Structural + referential integrity checks; powers `bin/rails survey:lint`.
  # Returns [ Issue(level: "error"|"warning", message:) ].
  module Lint
    Issue = Data.define(:level, :message)

    module_function

    def run(definition)
      issues = []
      err = ->(m) { issues << Issue.new(level: "error", message: m) }
      warn = ->(m) { issues << Issue.new(level: "warning", message: m) }

      err.("survey.id is missing") if definition.id.blank?
      err.("survey.editionId is missing") if definition.edition_id.blank?
      err.("survey.title is missing") if definition.title.blank?
      err.("survey.version is missing (recorded per response)") if definition.version.to_i.zero?

      section_ids = Set.new
      question_ids = {}
      definition.sections.each do |section|
        if section.id.blank? then err.("a section is missing its id")
        elsif section_ids.include?(section.id) then err.("duplicate section id: #{section.id}")
        else section_ids << section.id
        end
        warn.("section #{section.id.presence || '(?)'} has no title") if section.title.blank?

        section.questions.each do |q|
          where = "question #{q.id.presence || '(?)'} (section #{section.id})"
          if q.id.blank?
            err.("a question in section #{section.id} is missing its id")
            next
          end
          if question_ids.key?(q.id)
            err.("duplicate question id: #{q.id} (sections #{question_ids[q.id]}, #{section.id})")
          else
            question_ids[q.id] = section.id
          end
          warn.("#{where} has no prompt") if q.prompt.blank?

          unless q.known?
            err.("#{where} has unknown type \"#{q.type}\" (no renderer registered)")
            next
          end

          if q.choice?
            err.("#{where} (#{q.type}) has no options") if q.options.empty?
            seen = Set.new
            q.options.each do |o|
              if seen.include?(o.id) then err.("#{where} has duplicate option id: #{o.id}") else seen << o.id end
              warn.("#{where} option #{o.id} has an empty label") if o.label.blank?
            end
            if q.type == "multiple"
              err.("#{where} has invalid limit: #{q.limit}") if !q.limit.nil? && q.limit < 1
              q.exclusive_options.each do |ex|
                err.("#{where} exclusiveOptions references unknown option: #{ex}") unless seen.include?(ex)
              end
            end
          end

          if q.numeric?
            if !q.min.is_a?(Integer) || !q.max.is_a?(Integer) || q.min >= q.max
              err.("#{where} has invalid min/max: #{q.min}..#{q.max}")
            end
            if q.type == "scale"
              q.labels.each_key do |key|
                n = Integer(key, exception: false)
                warn.("#{where} has a label outside min..max: #{key}") if n.nil? || n < q.min || n > q.max
              end
            end
          end

          err.("#{where} has invalid maxLength: #{q.max_length}") if q.type == "text" && !q.max_length.nil? && q.max_length < 1
          err.("#{where} has invalid limit: #{q.limit}") if q.type == "text_list" && !q.limit.nil? && q.limit < 1

          if (show_if = q.show_if)
            target = definition.question(show_if.question_id)
            if target.nil?
              err.("#{where} showIf references unknown question: #{show_if.question_id}")
            else
              err.("#{where} showIf has empty values") if show_if.values.empty?
              if target.choice?
                target_ids = target.option_ids
                show_if.values.each do |v|
                  unless target_ids.include?(v) || v == OTHER_OPTION_ID
                    err.("#{where} showIf value \"#{v}\" is not an option of #{target.id}")
                  end
                end
              end
            end
          end
        end
      end
      issues
    end
  end
end
