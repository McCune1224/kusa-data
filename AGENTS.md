# kusa-data — AGENTS.md

SvelteKit 2 app for looking up Super Smash Bros. Ultimate tournament data from the [start.gg](https://start.gg) GraphQL API.

## Commands

| Command           | What it does                                                     |
| ----------------- | ---------------------------------------------------------------- |
| `npm run dev`     | Vite dev server with HMR                                         |
| `npm run build`   | Production build (Vercel adapter via `@sveltejs/adapter-vercel`) |
| `npm run preview` | Preview production build locally                                 |
| `npm run check`   | Runs `svelte-kit sync` then `svelte-check` (type-checking)       |
| `npm run lint`    | `prettier --check .`                                             |
| `npm run format`  | `prettier --write .`                                             |

**No test framework is configured.** No test scripts, no test runner, no test files exist.

## Environment Variables

Must be set before `npm run dev` or `npm run build` (loaded via `$env/static/private`):

| Variable       | Used in                      | Purpose                                     |
| -------------- | ---------------------------- | ------------------------------------------- |
| `REDIS_URL`    | `src/lib/redisClient.ts`     | Redis connection string for ioredis caching |
| `ACCESS_TOKEN` | `src/lib/startql/startgg.ts` | start.gg API bearer token                   |

`.env` and `.env.*` are gitignored. No `.env.example` currently exists — create a `.env` file locally.

## Architecture

- **Single package** — not a monorepo. No `packages/` or `apps/` directories.
- **Framework**: SvelteKit 2 with Svelte 4 (not Svelte 5). TypeScript strict mode.
- **Styling**: Tailwind CSS 3 + daisyUI 4 (`lemonade` theme). Use daisyUI class names (`link`, `btn`, `card`, `input`, etc.) for styled components.
- **Deployment**: Vercel via `@sveltejs/adapter-vercel`. No CI workflows in `.github/`.

### src/lib/ layout

- `src/lib/startql/` — start.gg GraphQL query layer. All queries are **hand-written** (`gql` tag + `parse()` from `graphql`). No codegen.
  - `startgg.ts` — GraphQL client with bearer token, tournament/participant queries
  - `player.ts` — Player lookup + paginated tournament history queries
  - `result_types.ts` — Hand-maintained TypeScript types for API responses
- `src/lib/redisClient.ts` — ioredis wrapper. Provides `jsonSet(key, value, ttl?)` with JSON serialization and 5-minute default TTL (`60 * 5000 = 300000ms`).
- **Redis caching is implemented only for player tournament history** (in `src/routes/players/[slug]/+page.server.ts`). Tournament participant lookups call start.gg directly every time.

### Routes

| Route                             | Type     | Purpose                                            |
| --------------------------------- | -------- | -------------------------------------------------- |
| `/`                               | Page     | Home page with tournament search widget            |
| `/tournaments/[slug]`             | SSR page | Lists all Smash Ultimate entrants for a tournament |
| `/players/[slug]`                 | SSR page | Shows a player's tournament history (Redis-cached) |
| `/api/tournaments/[slug]`         | API      | Tournament event info                              |
| `/api/tournaments/[slug]/players` | API      | Full participant list                              |
| `/api/event/[slug]/[gamerTag]`    | API      | Entrant standing                                   |

**Several API routes are incomplete stubs** (e.g. `/api/event`, `/api/players`).

### Key IDs & Limits

- **Smash Ultimate videogame ID**: `1386` (hardcoded in `startgg.ts` as `smashUltimateVideoGame`)
- **start.gg rate limit**: max 80 requests per 60 seconds, max 1000 objects per request (documented in `startgg.ts`)

## Conventions

- **Formatting**: Prettier with tabs, single quotes, no trailing commas, 100 print width. `*.svelte` files use the `svelte` parser.
- **No ESLint** — Prettier formatting is the only automated check.
- **npm**: `engine-strict=true` in `.npmrc` (Node engine requirements enforced).
- **Path aliases**: `$lib/` maps to `src/lib/` (SvelteKit default).

## Important

- `npm run check` runs `svelte-kit sync` first, which generates type definitions in `.svelte-kit/` (gitignored). Run `check` after modifying route params, layout structure, or `$env` usage.
- start.gg token format: `Bearer ${ACCESS_TOKEN}` (hardcoded in `startgg.ts`).
- Redis cache keys use the pattern `playerTournaments:{id}`.
- No CI/CD workflows in this repo — Vercel deploys likely via GitHub integration.
