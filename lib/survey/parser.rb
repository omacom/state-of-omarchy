module Survey
  # Raw yml Hash -> Definition. Throws ParseError only when the top-level shape is
  # unusable (no sections array). Individual questions are coerced with safe
  # fallbacks so one bad edit can never 500 the site — Survey::Lint exists to catch
  # those edits loudly in dev/CI instead.
  module Parser
    module_function

    def parse(data)
      root = as_hash(data)
      survey = as_hash(root["survey"])
      raw_sections = root["sections"]
      raise ParseError, "survey.yml must contain a top-level `sections` array" unless raw_sections.is_a?(Array)

      Definition.new(
        id: as_string(survey["id"]),
        edition_id: as_string(survey["editionId"]),
        year: as_integer(survey["year"], 0),
        title: as_string(survey["title"]),
        hashtag: survey["hashtag"].nil? ? nil : as_string(survey["hashtag"]),
        estimated_minutes: survey["estimatedMinutes"].is_a?(Integer) ? survey["estimatedMinutes"] : nil,
        version: as_integer(survey["version"], 0),
        sections: raw_sections.map { |s| parse_section(s) }
      )
    end

    def parse_section(raw)
      r = as_hash(raw)
      questions = r["questions"].is_a?(Array) ? r["questions"] : []
      Section.new(
        id: as_string(r["id"]),
        title: as_string(r["title"]),
        description: r["description"].nil? ? nil : as_string(r["description"]),
        questions: questions.map { |q| parse_question(q) }
      )
    end

    def parse_question(raw)
      q = as_hash(raw)
      type = as_string(q["type"])
      base = {
        id: as_string(q["id"]),
        type: type,
        prompt: as_string(q["prompt"]),
        required: q["required"] == true,
        show_if: parse_show_if(q["showIf"]),
        options: parse_options(q["options"])
      }

      case type
      when "single"
        Question.new(**base, allow_other: q["allowOther"] == true)
      when "multiple"
        Question.new(**base,
          allow_other: q["allowOther"] == true,
          limit: q["limit"].is_a?(Integer) ? q["limit"] : nil,
          exclusive_options: as_string_array(q["exclusiveOptions"]))
      when "scale"
        Question.new(**base,
          min: as_integer(q["min"], 1),
          max: as_integer(q["max"], 5),
          labels: parse_labels(q["labels"]))
      when "nps"
        Question.new(**base, min: as_integer(q["min"], 0), max: as_integer(q["max"], 10))
      when "text"
        Question.new(**base,
          max_length: q["maxLength"].is_a?(Integer) ? q["maxLength"] : nil,
          placeholder: q["placeholder"].nil? ? nil : as_string(q["placeholder"]))
      when "text_list"
        Question.new(**base,
          limit: q["limit"].is_a?(Integer) ? q["limit"] : nil,
          placeholder: q["placeholder"].nil? ? nil : as_string(q["placeholder"]))
      when "country"
        skip = as_hash(q["skipOption"])
        Question.new(**base,
          storage: q["storage"].nil? ? nil : as_string(q["storage"]),
          skip_option: skip["id"].is_a?(String) ? Question::Option.new(id: skip["id"], label: as_string(skip["label"])) : nil)
      else
        # Forward-compat: a type with no renderer yet. Carries what it can, never crashes.
        Question.new(**base)
      end
    end

    def parse_options(raw)
      return [] unless raw.is_a?(Array)
      raw.map { |o| as_hash(o) }
         .select { |o| o["id"].is_a?(String) }
         .map { |o| Question::Option.new(id: o["id"], label: as_string(o["label"])) }
    end

    def parse_show_if(raw)
      r = as_hash(raw)
      return nil unless r["questionId"].is_a?(String)
      Question::ShowIf.new(
        question_id: r["questionId"],
        op: r["op"] == "eq" ? "eq" : "includesAny",
        values: as_string_array(r["values"])
      )
    end

    def parse_labels(raw)
      return {} unless raw.is_a?(Hash)
      raw.to_h { |k, v| [ k.to_s, as_string(v) ] }
    end

    def as_hash(v) = v.is_a?(Hash) ? v : {}
    def as_string(v, fallback = "") = v.is_a?(String) ? v : fallback
    def as_integer(v, fallback) = v.is_a?(Integer) ? v : fallback
    def as_string_array(v) = v.is_a?(Array) ? v.select { |x| x.is_a?(String) } : []
  end
end
