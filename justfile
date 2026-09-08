default:
    @just --list

alias c := check
alias d := dev
alias t := test
alias sl := survey-lint
alias i := install
alias f := fix

# Everything CI runs: survey lint, rubocop, brakeman, and the test suite.
check:
    bin/rails survey:lint
    bin/rubocop
    bin/brakeman --no-pager -q
    bin/rails test

# Runs the test suite once.
test:
    bin/rails test

# Auto-fix what rubocop can fix.
fix:
    bin/rubocop -a

# Rails server + Tailwind watcher (Procfile.dev via foreman).
dev:
    bin/dev

# Install gems and prepare the SQLite databases.
install:
    bundle install
    bin/rails db:prepare

# Validates every surveys/<edition>/survey.yml (ids, showIf targets, option refs).
# Run after any edit to a survey yml.
survey-lint:
    bin/rails survey:lint

# Rebuild the Tailwind CSS once (bin/dev keeps it rebuilding).
css:
    bin/rails tailwindcss:build

# Rails console.
console:
    bin/rails console

# Database: migrations live in db/migrate, schema in db/schema.rb.
db-migrate:
    bin/rails db:migrate

# Wipe and recreate the local databases (dev + test).
db-reset:
    bin/rails db:reset

# Emails every waitlist signup that hasn't been notified yet that the survey is live.
# Run once on launch day, after SURVEY_LAUNCHED=true is deployed. Safe to re-run.
notify-waitlist:
    bin/rails waitlist:notify

# Deploy with Kamal (see config/deploy.yml and .kamal/secrets).
deploy:
    bin/kamal deploy

# Wipes local caches — reach for this when things behave oddly.
clean:
    rm -rf tmp/cache app/assets/builds/tailwind.css
