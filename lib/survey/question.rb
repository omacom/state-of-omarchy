module Survey
  class Question
    Option = Data.define(:id, :label)
    ShowIf = Data.define(:question_id, :op, :values)

    attr_reader :id, :type, :prompt, :show_if, :options, :limit, :exclusive_options,
                :min, :max, :labels, :max_length, :placeholder, :storage, :skip_option

    def initialize(id:, type:, prompt: "", required: false, show_if: nil, options: [], allow_other: false,
                   limit: nil, exclusive_options: [], min: nil, max: nil, labels: {}, max_length: nil,
                   placeholder: nil, storage: nil, skip_option: nil)
      @id = id
      @type = type
      @prompt = prompt
      @required = required
      @show_if = show_if
      @options = options
      @allow_other = allow_other
      @limit = limit
      @exclusive_options = exclusive_options
      @min = min
      @max = max
      @labels = labels
      @max_length = max_length
      @placeholder = placeholder
      @storage = storage
      @skip_option = skip_option
    end

    def required? = @required
    def allow_other? = @allow_other
    def known? = Survey.known_type?(type)
    def choice? = type == "single" || type == "multiple"
    def numeric? = type == "scale" || type == "nps"

    def option_ids
      options.map(&:id)
    end

    # Options as rendered: appends the generic "Other" entry when allowOther is set
    # and the yml didn't list one explicitly.
    def options_for_display
      if allow_other? && option_ids.exclude?(OTHER_OPTION_ID)
        options + [ Option.new(id: OTHER_OPTION_ID, label: "Other") ]
      else
        options
      end
    end

    def option_label(option_id)
      options.find { |o| o.id == option_id }&.label || option_id
    end

    # DOM id of the prompt element; every renderer labels its inputs with it.
    def dom_id = "q-#{id}"
  end
end
