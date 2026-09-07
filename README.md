<div align="center">
<img src="./src/lib/assets/soo-logo.png" width="300">
</div>

Yearly survey for Omarchy Linux.

- [x] Waitlist feature before launch.
- [x] Passwordless auth (email link or code) -> one response per account.
- [x] Questionnaire driven entirely by `src/lib/surveys/<year>/survey.yml`.
- [ ] Report: Charts and visualizations of survey results (After survey is launched).

## Architecture

SvelteKit app (adapter-node) backed by Turso (libsql via Drizzle) and Better Auth for
passwordless (magic link / OTP) sign-in, with Resend for email delivery.

## Development

Clone the project and install dependencies with `pnpm install`, then copy `.env.example` to `.env` and fill in the values below.

```sh
pnpm install
cp .env.example .env   # then fill in the values below
```

| Variable                               | Purpose                                                                                |
| -------------------------------------- | -------------------------------------------------------------------------------------- |
| `DATABASE_URL` / `DATABASE_AUTH_TOKEN` | Turso database (for dev: `file:local.db`)                                              |
| `ORIGIN`                               | App URL (`http://localhost:5173` in dev)                                               |
| `BETTER_AUTH_SECRET`                   | Auth secret (`openssl rand -base64 32`)                                                |
| `RESEND_API_KEY`                       | Resend key (leave empty in dev: magic links & OTP codes print in the terminal instead) |
| `RESEND_FROM`                          | Verified sender, needed for real delivery                                              |
| `SURVEY_LAUNCHED`                      | `false`/unset shows the waitlist on `/`; `true` opens the real survey (see below)      |

Push the schema, then start developing:

```sh
pnpm db:push --force   # creates auth + survey tables (dev only; use generate+migrate in prod)
pnpm dev
```

## Pre-launch Waitlist

The site can go live before the survey itself opens. While `SURVEY_LAUNCHED` is `false`/unset,
`/` shows a simple email-capture waitlist instead of the sign-in flow, and every `/survey*`
route redirects home regardless of session state — so there's no way to reach the survey early.
Signups live in the `waitlist_signups` table (`src/lib/server/db/waitlist.schema.ts`); the
same email can submit more than once without erroring (it's just told it's already on the list).

**Launch day:**

1. Set `SURVEY_LAUNCHED=true` in the environment and redeploy. `/` now shows the normal
   passwordless sign-in flow, and `/survey*` is reachable again.
2. Email everyone who joined the waitlist:

   ```sh
   pnpm notify:waitlist   # or: just notify-waitlist
   ```

   This runs standalone (outside SvelteKit/Vite), reading `.env` directly. It only emails
   addresses that haven't been notified yet, marking each as sent as it goes — so if a run
   fails partway through, re-running it just retries what's left.

## Survey Questions

Editing questions or options in `src/lib/surveys/<year>/survey.yml` needs no code changes:
renderers, validation, storage, and progress are all derived from the yml by type.

Run `pnpm survey:lint` after editing. It fails on duplicate ids, unknown types, and broken `showIf` references.

```sh
pnpm survey:lint  # validate survey.yml — run after ANY question/option edit
```

New edition = new `src/lib/surveys/<year>/` directory;

## Building

To create a production version of the app:

```sh
pnpm build
```

You can preview the production build with `pnpm preview`.
