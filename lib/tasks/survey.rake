namespace :survey do
  desc "Validate every surveys/<edition>/survey.yml (ids, showIf targets, option refs). Fails on errors."
  task lint: :environment do
    errors = warnings = 0
    editions = Survey::Loader.editions
    abort "No surveys/<edition>/survey.yml found under #{Survey::Loader.root}" if editions.empty?

    editions.each do |edition|
      puts "\n--- #{edition}/survey.yml ---"
      begin
        definition = Survey::Loader.load(edition, reload: true)
      rescue Survey::ParseError, Psych::SyntaxError => e
        errors += 1
        puts "  ERROR: unparseable file (#{e.message})"
        next
      end
      issues = Survey::Lint.run(definition)
      puts "  OK" if issues.empty?
      issues.each do |issue|
        if issue.level == "error"
          errors += 1
          puts "  ERROR: #{issue.message}"
        else
          warnings += 1
          puts "  warning: #{issue.message}"
        end
      end
    end

    puts "\n#{errors} error(s), #{warnings} warning(s)"
    exit(errors > 0 ? 1 : 0)
  end
end
