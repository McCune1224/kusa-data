# KUSA DATA

**Melee tournament browsing, reimagined.** A fast, beautiful dashboard for the
Super Smash Bros. Melee scene: discover upcoming tournaments, dig into seeds
and results, and get per-player match analytics — all powered by the
[start.gg GraphQL API](https://developer.start.gg) and cached in Redis.

Built with **Elixir**, **Phoenix LiveView**, **Tailwind CSS v4** and **Redix**.

---

## ✨ Features

| Area | What you get |
| --- | --- |
| **Tournament browser** | Upcoming Melee majors worldwide, or filtered by postal code + radius with geocoding (Zippopotam.us / Open-Meteo). |
| **Event brackets** | Full seeding lists and final standings with placement highlighting and live tag filtering. |
| **Player search** | No global start.gg index exists — so we scan recent tournament rosters for a tag, exact-match first. |
| **Player analytics** | On-demand win/loss record, win rate, character usage, head-to-head records and recent sets, computed from their last several hundred sets. |
| **Link parser** | Paste any start.gg tournament/event URL or slug and jump straight to the bracket. |
| **Redis cache** | A defensive layer keeps repeated queries off your start.gg quota; degrades gracefully to uncached when Redis is unavailable. |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Phoenix LiveView  ·  server-rendered, real-time           │
│  ┌───────────────┐   ┌───────────────┐   ┌───────────────┐  │
│  │ Home / browse │   │ Event/seed &  │   │ Player stats  │  │
│  │ and search    │   │ standings     │   │ + analytics   │  │
│  └───────┬───────┘   └───────┬───────┘   └───────┬───────┘  │
└──────────┼───────────────────┼───────────────────┼─────────┘
           └───────────────┬───┴───┬───────────────┘
                           ▼       ▼
                   ┌──────────────┐  ┌─────────────────────────┐
                   │ KusaData.Cache │  │ GraphQL client          │
                   │ (Redis /       │  │ ·  rate-limited          │
                   │  graceful      │  │ ·  retry on 429          │
                   │  degrade)      │  │ ·  never raises          │
                   └──────┬───────┘  └───────────┬─────────────┘
                          │                      ▼
                   ┌──────▼────────┐   ┌─────────────────────────┐
                   │ Geocode layer │   │ start.gg GraphQL API    │
                   └───────────────┘   └─────────────────────────┘
```

Notable modules:

- `KusaData.Tournaments` / `KusaData.Events` — cached list + detail fetches with
  multi-page fan-out (`Task.async_stream`).
- `KusaData.Players` — roster scan search + identity lookup.
- `KusaData.Stats` / `KusaData.Stats.Engine` — set-history pagination and
  composition of the analytics payload.
- `KusaData.Cache` / `KusaData.Redis` — Redis-backed cache with an in-memory
  fake for tests and automatic `:bypass` degradation.
- `KusaData.GraphQL.*` — the full client stack: bearer auth, rate limiting,
  retry on `429`, typed error handling.

## 🚀 Getting started

Requirements: Elixir ≥ 1.17, Phoenix 1.8 toolchain, and (optionally) Redis.

```bash
# 1. Install dependencies and build assets
mix setup

# 2. Configure your start.gg API token
cp .env.example .env
#    then paste your token into ACCESS_TOKEN=
#    (a free public token "startgg" works for light testing)

# 3. Start the server (Redis optional — without it the app runs uncached)
source .env && mix phx.server
```

Visit **<http://localhost:4000>**.

## 🧪 Testing

The suite uses a fake Redis (`KusaData.FakeRedis`) and a fake HTTP transport,
so it runs fully offline:

```bash
mix test          # 56 tests · contexts, cache, GraphQL client, engine
mix precommit     # compile --warnings-as-errors + format + full suite
```

## 🛠️ Configuration

| Variable | Purpose |
| --- | --- |
| `ACCESS_TOKEN` | start.gg API bearer token (see [docs](https://developer.start.gg)). |
| `REDIS_URL` | Optional; when absent the app bypasses the cache. |
| `PORT` / `PHX_HOST` / `SECRET_KEY_BASE` | Standard Phoenix runtime settings. |

## 📄 License

Personal/portfolio project. Data belongs to start.gg and its tournament
organizers.