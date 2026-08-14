# Kusa Data

Melee tournament analytics — bracket lookup, seed placement finder, and player stat analysis
built on the [start.gg](https://start.gg) GraphQL API.

Phoenix 1.8 + LiveView, Ecto + Postgres, Redis cache, Tailwind v4. Deploy target: Fly.io.

## Setup

```sh
# 1. Postgres + Redis (docker)
docker run -d --name kusa-pg -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 postgres:16
docker run -d --name kusa-redis -p 6379:6379 redis:7

# 2. Install deps, DB, assets
mix setup

# 3. Env
cp .env.example .env   # fill in ACCESS_TOKEN (start.gg) and REDIS_URL

# 4. Seed games + crawl a slice of live data (optional)
mix run priv/repo/seeds.exs
mix run -e 'KusaData.Crawl.run(1)'
```

## Commands

- `mix phx.server` — dev server (port 4000)
- `mix test` — ExUnit suite
- `mix precommit` — warnings-as-errors compile, format, test (run before finishing)
- `mix credo` — lint

See `AGENTS.md` for architecture, conventions, and milestones.
