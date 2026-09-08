module Survey
  # Discriminated answer value, keyed by question id in an answers Hash.
  #
  #   empty     — nothing answered
  #   single    — option_id (+ other write-in)
  #   multiple  — option_ids (+ other write-in)
  #   number    — value (scale / nps)
  #   text      — text
  #   list      — items (text_list)
  #   country   — code (iso2 or the skip option id)
  class Value
    KINDS = %w[ empty single multiple number text list country ].freeze

    attr_reader :kind, :option_id, :option_ids, :other, :value, :text, :items, :code

    def self.empty = new(kind: "empty")
    def self.single(option_id, other: nil) = new(kind: "single", option_id: option_id.to_s, other: other)
    def self.multiple(option_ids, other: nil) = new(kind: "multiple", option_ids: option_ids.map(&:to_s).uniq, other: other)
    def self.number(value) = new(kind: "number", value: value)
    def self.text(text) = new(kind: "text", text: text.to_s)
    def self.list(items) = new(kind: "list", items: items.map(&:to_s))
    def self.country(code) = new(kind: "country", code: code.to_s)

    def initialize(kind:, option_id: nil, option_ids: [], other: nil, value: nil, text: nil, items: [], code: nil)
      raise ArgumentError, "unknown value kind #{kind.inspect}" unless KINDS.include?(kind)
      @kind = kind
      @option_id = option_id
      @option_ids = option_ids
      @other = other
      @value = value
      @text = text
      @items = items
      @code = code
    end

    def empty? = kind == "empty"

    # Trimmed "Other" write-in, nil when blank.
    def other_text
      other.to_s.strip.presence
    end

    # Flatten to comparable id strings for showIf evaluation.
    def ids
      case kind
      when "single" then option_id.present? ? [ option_id ] : []
      when "multiple" then option_ids
      when "country" then code.present? ? [ code ] : []
      when "number" then value.nil? ? [] : [ value.to_s ]
      when "text" then text.to_s.strip.empty? ? [] : [ text.strip ]
      when "list" then items.map(&:strip).reject(&:empty?)
      else []
      end
    end

    # Coerce untrusted form params into a Value matching the question's type.
    # Shape mismatches never raise — they simply become empty, and the question's
    # validation then reports whatever is missing. Unknown types are always empty.
    def self.from_params(question, raw)
      return empty unless question.known?
      raw = raw.respond_to?(:to_h) ? raw.to_h : {}
      raw = raw.transform_keys(&:to_s)

      case question.type
      when "single"
        option_id = raw["option_id"].to_s
        option_id.empty? ? empty : single(option_id, other: raw["other"].is_a?(String) ? raw["other"] : nil)
      when "multiple"
        ids = Array(raw["option_ids"]).select { |x| x.is_a?(String) && !x.empty? }
        ids.empty? ? empty : multiple(ids, other: raw["other"].is_a?(String) ? raw["other"] : nil)
      when "scale", "nps"
        v = raw["value"]
        return empty if v.nil? || v.to_s.strip.empty?
        Integer(v.to_s, exception: false).nil? ? new(kind: "number", value: v.to_s) : number(Integer(v.to_s))
      when "text"
        t = raw["text"]
        t.is_a?(String) && !t.strip.empty? ? text(t) : empty
      when "text_list"
        items = Array(raw["items"]).select { |x| x.is_a?(String) }
        items.any? { |i| !i.strip.empty? } ? list(items) : empty
      when "country"
        c = raw["code"].to_s
        c.empty? ? empty : country(c)
      else
        empty
      end
    end

    def to_h
      case kind
      when "single" then { kind:, option_id:, other: }.compact
      when "multiple" then { kind:, option_ids:, other: }.compact
      when "number" then { kind:, value: }
      when "text" then { kind:, text: }
      when "list" then { kind:, items: }
      when "country" then { kind:, code: }
      else { kind: }
      end
    end

    def ==(other)
      other.is_a?(Value) && to_h == other.to_h
    end
    alias eql? ==

    def hash = to_h.hash
  end
end
