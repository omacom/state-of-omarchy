## State of Omarchy - survey project

This is a web application for a yearly survey on [Omarchy Linux](https://omarchy.org). Users can participate in the survey to provide feedback on the project.

## Project Configuration

- **Framework**: Ruby on Rails 8 (see `.ruby-version`), Minitest
- **Front end**: Hotwire (Turbo + Stimulus via importmap), Tailwind CSS v4 through `tailwindcss-rails` (standalone CLI, no Node)
- **Database**: SQLite (primary + Solid Queue + Solid Cache)
- **Email**: Action Mailer over Resend SMTP; passwordless sign-in (magic link + code) modelled on Fizzy
- **Deploy**: Docker image via Kamal (`config/deploy.yml`, `.kamal/secrets`)

---

UI is built from the component classes in `app/assets/tailwind/application.css` (`btn`, `card`,
`input`, `dialog`, …) which port the shadcn recipes the previous SvelteKit app used. Reuse them
before adding new ones; keep the Tokyo Night tokens as the only source of color.

Use `just check` (survey lint, rubocop, brakeman, tests) before finishing a change.

## Data-driven survey rule (hard rule, all editions)

`surveys/<year>/survey.yml` is the single source of truth for website, components,
and backend. Adding, editing, reordering, or removing questions, options, and sections must
work without touching code — and must never break the site:

- Renderers are keyed ONLY by question `type` (`single`, `multiple`, `scale`, `nps`, `text`,
  `text_list`, `country`) — see `app/views/surveys/questions/_<type>.html.erb`. NEVER branch UI,
  validation, storage, or results logic on a specific question/section id.
- Validation, `showIf` evaluation, limits, `allowOther`, `exclusiveOptions`, and completion
  are derived generically from yml attributes in `lib/survey/definition.rb`, on both server
  (authoritative) and client (Stimulus, for instant feedback only).
- Unknown future `type` values must render the graceful "unsupported question" fallback
  (`_unsupported.html.erb`), never crash.
- Referential integrity of the yml (unique ids, valid `showIf` targets, valid option refs) is
  enforced by `bin/rails survey:lint`, not by hand-checking. Run it after any yml edit.
- Editions are isolated by directory (`surveys/2027/survey.yml`, …) + `edition_id` in the DB.
  New editions reuse all code unchanged; never rename a shipped question/option id (add new ones).
