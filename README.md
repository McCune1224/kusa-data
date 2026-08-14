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

## Deploy (Fly.io)

Config is generated (`Dockerfile`, `fly.toml`, `rel/overlays/bin/server`) — deploying
requires `flyctl` and a Fly account:

```sh
fly launch --no-deploy            # or adopt this repo with: fly apps create
fly secrets set ACCESS_TOKEN=… REDIS_URL=… DATABASE_URL=… SECRET_KEY_BASE=$(mix phx.gen.secret)
fly deploy
```

Postgres and Redis run as Fly managed services (or anywhere reachable);
`DATABASE_URL` and `REDIS_URL` point at them. The crawler is manual for now:
`fly ssh console -C "/app/bin/kusa_data eval 'KusaData.Crawl.run(1)'"`.

See `AGENTS.md` for architecture, conventions, and milestones.
