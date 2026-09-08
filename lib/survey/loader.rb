

module Survey
  # Reads `surveys/<edition>/survey.yml`. New edition = new directory, zero code
  # changes. Parsed definitions are cached per process; in development the file
  # is re-read whenever its mtime changes so yml edits show up on reload.
  module Loader
    Entry = Struct.new(:definition, :mtime)

    class << self
      attr_writer :root

      def root
        @root ||= File.expand_path("../../surveys", __dir__)
      end

      def editions
        Dir.glob(File.join(root, "*", "survey.yml")).map { |p| File.basename(File.dirname(p)) }.sort
      end

      def path_for(edition)
        File.join(root, edition.to_s, "survey.yml")
      end

      def load(edition, reload: false)
        path = path_for(edition)
        unless File.file?(path)
          raise UnknownEditionError, "Unknown survey edition #{edition.inspect} (available: #{editions.join(', ').presence || 'none'})"
        end
        mtime = File.mtime(path)
        entry = cache[edition.to_s]
        return entry.definition if entry && !reload && entry.mtime == mtime

        definition = Parser.parse(Yaml.load_file(path))
        cache[edition.to_s] = Entry.new(definition, mtime)
        definition
      end

      def reset!
        @cache = {}
      end

      private
        def cache
          @cache ||= {}
        end
    end
  end
end
