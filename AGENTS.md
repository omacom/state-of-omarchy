## State of Omarchy - survey project

This is a web application for a yearly survey on [Omarchy Linux](https://oomarchy.org). Users can participate in the survey to provide feedback on the project.

## Project Configuration

- **Language**: TypeScript
- **Package Manager**: pnpm
- **Add-ons**: prettier, eslint, tailwindcss, sveltekit-adapter, drizzle, better-auth, ai-tools
- **UI Components**: shadcn-svelte
- **Database**: Turso (libsql)
- **Email service**: Resend for email verification & magic links

---

Always use shadcn-svelte UI components for UI elements.

Use `just c` to check the codebase for any issues or suggestions.

## Data-driven survey rule (hard rule, all editions)

`src/lib/surveys/<year>/survey.yml` is the single source of truth for website, components,
and backend. Adding, editing, reordering, or removing questions, options, and sections must
work without touching code — and must never break the site:

- Renderers are keyed ONLY by question `type` (`single`, `multiple`, `scale`, `nps`, `text`,
  `text_list`, `country`). NEVER branch UI, validation, storage, or results logic on a
  specific question/section id.
- Validation, `showIf` evaluation, limits, `allowOther`, `exclusiveOptions`, and completion
  are derived generically from yml attributes, on both client and server.
- Unknown future `type` values must render a graceful "unsupported question" fallback, never crash.
- Referential integrity of the yml (unique ids, valid `showIf` targets, valid option refs) is
  enforced by `pnpm survey:lint`, not by hand-checking. Run it after any yml edit.
- Editions are isolated by directory (`surveys/2027/survey.yml`, …) + `edition_id` in the DB.
  New editions reuse all code unchanged; never rename a shipped question/option id (add new ones).

You are able to use the Svelte MCP server, where you have access to comprehensive Svelte 5 and SvelteKit documentation. Here's how to use the available tools effectively:

## Available Svelte MCP Tools:

### 1. list-sections

Use this FIRST to discover all available documentation sections. Returns a structured list with titles, use_cases, and paths.
When asked about Svelte or SvelteKit topics, ALWAYS use this tool at the start of the chat to find relevant sections.

### 2. get-documentation

Retrieves full documentation content for specific sections. Accepts single or multiple sections.
After calling the list-sections tool, you MUST analyze the returned documentation sections (especially the use_cases field) and then use the get-documentation tool to fetch ALL documentation sections that are relevant for the user's task.

### 3. svelte-autofixer

Analyzes Svelte code and returns issues and suggestions.
You MUST use this tool whenever writing Svelte code before sending it to the user. Keep calling it until no issues or suggestions are returned.

### 4. playground-link

Generates a Svelte Playground link with the provided code.
After completing the code, ask the user if they want a playground link. Only call this tool after user confirmation and NEVER if code was written to files in their project.
