module Survey
  class Section
    attr_reader :id, :title, :description, :questions

    def initialize(id:, title:, description: nil, questions: [])
      @id = id
      @title = title
      @description = description
      @questions = questions
    end
  end
end
