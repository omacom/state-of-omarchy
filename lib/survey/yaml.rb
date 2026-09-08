require "psych"

module Survey
  # YAML loading that keeps `yes`/`no`/`on`/`off` as strings. Psych follows YAML 1.1
  # and would otherwise turn an option like `- id: no` into `false`, silently dropping
  # it from the survey. Everything else is plain safe_load (no arbitrary objects).
  module Yaml
    class ScalarScanner < Psych::ScalarScanner
      LITERAL_WORDS = /\A(?:y|yes|n|no|on|off)\z/i

      def tokenize(string)
        return string if string.is_a?(String) && string.match?(LITERAL_WORDS)
        super
      end
    end

    def self.load(text)
      tree = Psych.parse(text)
      return {} unless tree
      class_loader = Psych::ClassLoader::Restricted.new([], [])
      scanner = ScalarScanner.new(class_loader)
      Psych::Visitors::ToRuby.new(scanner, class_loader).accept(tree)
    end

    def self.load_file(path)
      load(File.read(path))
    end
  end
end
