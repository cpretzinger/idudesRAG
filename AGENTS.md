# Repository Guidelines

## Project Structure & Module Organization
- `ui/` — Next.js 15 TypeScript app (app router, Tailwind). Auth helpers in `ui/lib/` and context in `ui/contexts/`.
- `processor/` — Node/Express utilities (optional worker).
- `migrations/` — SQL schemas and changes (prefer schema `core` where applicable).
- `json-flows/` — n8n authentication and automation flows (e.g., `03-auth-reset-password.json`, `04-auth-login.json`, `05-auth-validate.json`).
- `scripts/` — setup, deploy, and data helpers (e.g., `scripts/setup.sh`, `scripts/add-users.js`).
- `documentation/` — ops, deployment, and architecture guides; includes a Makefile with helpful targets.

## Build, Test, and Development Commands
- UI dev: `cd ui && npm install && npm run dev` (runs Next.js on `:3000`).
- UI build/start: `cd ui && npm run build && npm start`.
- Make targets: `make -C documentation help | dev | build | docker-up | test-db`.
- Apply DB schema: `psql <connection> -f migrations/auth-simple-schema.sql` (and other files in `migrations/`).
- Lint: `cd ui && npm run lint`.

## Coding Style & Naming Conventions
- TypeScript, 2-space indent, ESLint (`ui/eslint.config.mjs`). Prefer functional React components and `app/` router patterns.
- Filenames: kebab-case for files, PascalCase for React components, snake_case for SQL identifiers.
- JSON flows: two-digit, descriptive prefixes (e.g., `03-…`, `04-…`).

## Testing Guidelines
- UI smoke: verify routes render and API calls succeed (use `documentation/Makefile` `test-*` targets where available).
- Database: run verification queries included at the bottom of migration files.
- Add unit tests in UI when modifying logic-heavy modules in `ui/lib/`.

## Commit & Pull Request Guidelines
- Commits: imperative, scoped messages (e.g., `feat(ui): add auth validate handler`).
- PRs: clear description, linked issues, before/after screenshots for UI, steps to reproduce/test, and DB migration notes when applicable.

## Security, Config, and SOT (10-12-25)
- Source of Truth (SOT): Use configs, env vars, and DB schemas as of 10-12-25.
  - Env: `.env` and `.env.example` values dated 10-12-25.
  - DB: prefer `migrations/` SQL (10-12-25 versions) and `core` schema objects.
  - App: `ui/` config files (Next.js, ESLint, Tailwind) as present on 10-12-25.
- Never commit secrets. Mirror required vars from `.env.example` and docs.
- Log auth events to `core.auth_logs`; do not emit secrets in logs.

## Agent-Specific Notes
- Keep changes focused; follow this file’s conventions. When touching multiple areas (UI, SQL, flows), update related docs and migrations together.
