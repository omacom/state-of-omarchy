<div align="center">
<img src="./app/assets/images/soo-logo.png" width="300">
</div>

Yearly survey for Omarchy Linux.

- [x] Waitlist feature before launch.
- [x] Passwordless auth (email link or code) -> one response per account.
- [x] Questionnaire driven entirely by `surveys/<year>/survey.yml`.
- [ ] Report: Charts and visualizations of survey results (After survey is launched).

## Architecture

A self-contained Ruby on Rails 8 app: SQLite for the database (Solid Queue and Solid Cache
run on it too), Hotwire (Turbo + Stimulus) for the front end, Tailwind CSS compiled by the
standalone CLI (no Node), and Resend (over SMTP) for email. Deployed as a single container
with Kamal.

Sign-in is passwordless and modelled on [Fizzy](https://github.com/basecamp/fizzy): entering
an email mints a `MagicLink` with a 6-character code and a long single-use token, both
expiring in 15 minutes. The code only works in the browser that requested it (a signed,
short-lived cookie carries the pending email address); the emailed link works from any device.
Either consumes the link and starts a `Session` row referenced by a signed cookie.

```
app/controllers/concerns/authentication.rb     session cookie <-> Session row
app/controllers/concerns/authentication/       pending-email cookie for the typed code
app/models/magic_link.rb                       code + token, expiry, consume, cleanup
lib/survey/                                    yml -> definition, visibility, validation, progress, lint
app/models/response.rb, answer.rb              one response per user per edition; normalized answers
app/views/surveys/                             one page per section; autosave via Turbo Streams
app/javascript/controllers/                    Stimulus: autosave, showIf, choice limits, slider, lists
```

## Development

Requires Ruby (see `.ruby-version`); everything else is a gem. Copy `.env.example` only if
you want to override defaults — nothing is required locally.

```sh
bundle install
bin/rails db:prepare
bin/dev            # Rails server + Tailwind watcher on http://localhost:3000
```

In development the survey is launched by default and no email is sent: the sign-in code
and link are shown on the "check your inbox" page and in the server log.

| Variable          | Purpose                                                                                       |
| ----------------- | --------------------------------------------------------------------------------------------- |
| `APP_HOST`        | Public origin without scheme (`localhost:3000` in dev). Used for emailed links and og tags.   |
| `RESEND_API_KEY`  | Resend key; production delivers through `smtp.resend.com:465` with username `resend`.         |
| `MAILER_FROM`     | Verified sender, needed for real delivery.                                                     |
| `SURVEY_LAUNCHED` | `false`/unset shows the waitlist on `/`; `true` opens the survey. Dev defaults to `true`.     |
| `SURVEY_EDITION`  | Edition served at `/survey` (a directory under `surveys/`). Defaults to `2026`.                |

Useful commands (see `justfile`):

```sh
just check           # survey lint + rubocop + brakeman + tests (what CI runs)
just test            # bin/rails test
just survey-lint     # validate surveys/*/survey.yml — run after ANY question/option edit
just notify-waitlist # launch-day email to everyone on the waitlist
```

## Pre-launch Waitlist

While `SURVEY_LAUNCHED` is `false`/unset, `/` shows a simple email-capture waitlist instead
of the sign-in flow, and every `/survey*` and sign-in route redirects home regardless of
session state. Signups live in `waitlist_signups`; the same email can submit more than once
without erroring (it's just told it's already on the list).

**Launch day:**

1. Set `SURVEY_LAUNCHED: "true"` in `config/deploy.yml` and `kamal deploy`.
2. Email everyone who joined the waitlist:

   ```sh
   kamal notify-waitlist      # alias for: bin/rails waitlist:notify inside the container
   ```

   Only addresses that haven't been notified yet are emailed, each marked as sent as it
   goes — re-running after a partial failure just retries what's left.

## Survey Questions

Editing questions or options in `surveys/<year>/survey.yml` needs no code changes:
renderers, validation, storage and progress are all derived from the yml by question type.

```sh
bin/rails survey:lint   # fails on duplicate ids, unknown types, broken showIf references
```

New edition = new `surveys/<year>/` directory + `SURVEY_EDITION=<year>`.

## Deployment

Kamal builds the `Dockerfile` and runs it behind kamal-proxy with automatic SSL. The SQLite
databases live on the `soo_storage` volume — back that volume up.

```sh
export KAMAL_REGISTRY_PASSWORD=... RESEND_API_KEY=...   # read by .kamal/secrets
kamal setup      # first time
kamal deploy     # every time after
kamal console    # rails console in production
```

Edit `config/deploy.yml` for the server IP, hostname, registry and `APP_HOST`. Recurring
jobs (expired magic-link cleanup) run inside the app container via Solid Queue.
