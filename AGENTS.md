# Kusa Data — AGENTS.md

Professional FGC tournament analytics: **bracket lookup, seed placement finder, player stat analysis**.
Melee-only data. Phoenix LiveView app living at the repo root (the old SvelteKit app was deleted
on 2026-08-14 — do not reference it; its only surviving artifact is the env vars below).

## Commands

| Command                                          | What it does                                                       |
| ------------------------------------------------ | ------------------------------------------------------------------ |
| `mix test`                                       | Creates/migrates test DB, runs ExUnit (requires `kusa-pg` running) |
| `mix precommit`                                  | `compile --warnings-as-errors`, `deps.unlock --unused`, `format`, `test` — run before finishing |
| `mix format --check-formatted`                   | Formatting check                                                   |
| `mix credo`                                      | Lint (strict)                                                      |
| `mix phx.server`                                 | Dev server on port 4000                                            |
| `mix run priv/repo/seeds.exs`                    | Seed known games (idempotent)                                      |

## Environment Variables

Loaded from `System.get_env` at runtime (dev/test/prod). `.env` and `.env.*` are gitignored;
`.env.example` documents them. To load `.env` for one-off scripts:
`set -a; . ./.env; set +a; mix run -e ...`

| Variable        | Used in                              | Purpose                                                        |
| --------------- | ------------------------------------ | -------------------------------------------------------------- |
| `ACCESS_TOKEN`  | `KusaData.GraphQL.Client`            | start.gg API bearer token (required for live API calls)        |
| `REDIS_URL`     | `KusaData.Cache` (cache layer)       | Redis connection string; app degrades gracefully without it    |
| `DATABASE_URL`  | `config/runtime.exs` (prod only)     | Ecto Postgres URL                                               |
| `SECRET_KEY_BASE`, `PHX_HOST` | prod runtime config | Required in prod                                                |

## Stack

- Elixir 1.20.3 + OTP 29 (via asdf), Phoenix 1.8.9, LiveView, Ecto 3 + Postgres 16
  (docker container `kusa-pg`, port 5432), Req (HTTP client), Bypass (HTTP mocking),
  ExUnit + `Phoenix.LiveViewTest`, Credo.
- **Redis** (docker container `kusa-redis`, port 6379) is the **cache layer in front of
  on-demand start.gg fetches** (set details, character/stage data). The start.gg API is the
  source for base info; Postgres is the source of truth for crawled rankings data. If Redis
  is down, features degrade to uncached API calls — never fail hard.
- Deploy target: **Fly.io** (Dockerfile). Not deployed yet.

## Architecture

- `lib/kusa_data/graphql/` — start.gg client. Typed query builders (pure functions), a token
  bucket honoring 80 req/min, exponential backoff on 429 (1.5s→3s→6s→12s, 4 retries), 15s timeout,
  no retry on validation/complexity errors. HTTP tests via Bypass (200 / 429 / complexity / hang).
- `lib/kusa_data/elo.ex` — **pure** Elo engine: `expected_score/2`, `apply_set/3` (K=32, seed 1500,
  tie = 0.5/0.5, symmetric W/L tallies, state==3 + both users + scores required). Unit-tested.
- `lib/kusa_data/crawl/` — supervised GenServer + queue for the rankings crawler:
  window-walk (7-day slices backward to 90 days, cursor in Postgres `crawl_state`), seen-set,
  singles-event preference (no doubles pollution), per-tournament error isolation (a failure never
  stalls the slice), chronological set application (Elo path-independence), per-game isolation.
  Fixture-driven tests + Bypass for HTTP; never hits real start.gg in unit tests.
- `lib/kusa_data/search.ex` — player search: Postgres index (crawled players) first, live
  participant scan fallback when no exact match, exact > prefix > substring ranking.
- `lib/kusa_data_web/live/` — LiveViews: Home (hero + search combobox), Rankings
  (leaderboard + filter), Player (stats, set history, char/stage breakdown), PlayerSearch
  (`/players?q=`), VS (two-panel compare + H2H), Tournament (roster + seed finder).
- `lib/kusa_data/cache.ex` — Redis cache wrapper (Redix) for on-demand start.gg responses;
  degrades to uncached fetches when Redis is unavailable.

## Data model (Ecto)

`games`, `players` (start.gg user id + player id, gamer_tag, prefix), `tournaments`, `events`,
`entrants`, `sets` (unique on start.gg set id; scores + winner/loser only — **no games/chars/
stages in Postgres**), `ratings` (game_id, player_id unique, elo, sets, wins, losses),
`crawl_state` (per-game window cursor + seen tournament ids). Migrations ship with tests;
schema changes are test-first.

**Game-level detail (characters, stages, per-game scores) is fetched on demand from start.gg
and cached in Redis — never stored in Postgres.**

## Key facts & gotchas

- **Melee videogameId on start.gg is `1`** (`1386` is Smash Ultimate — a copy-paste bug in
  seeds/tests was fixed 2026-08-14; dev DB was wiped and re-crawled).
- start.gg rate limit: max 80 requests per 60 seconds, max 1000 objects per request.
- Dev DB `kusa_data_dev` currently holds one crawled slice (10 tournaments / 103 sets / 59 players).

## UI Standard (professional — the point of the rewrite)

- **Design tokens only, no inline hex**: spacing scale, type scale (16px base, supporting text
  ≥14px), a calm light "paper" palette (warm off-white background, near-black text, **one**
  restrained accent). No gradients, no text strokes, no neon, no glow.
- **Every surface has three states**: loading, empty, error — never a bare spinner.
- **WCAG AA**: ≥4.5:1 text contrast, ≥3:1 UI boundaries, visible focus everywhere, aria labels,
  keyboard-navigable menu and search combobox.
- **Mobile-first**: collapsing header, `overflow-x` tables with sticky headers, ≥44px touch targets.
- **One component kit** in LiveView (card, badge, table, stat-grid, empty-state) — single
  definitions, reused everywhere. No per-page ad-hoc styling.
- **daisyUI is to be removed.** The phx scaffold ships with it and `SearchLive` currently uses its
  classes (`input input-bordered`, `btn`, `badge`); the component kit replaces it. Tailwind v4
  (no config file) is the styling tool.

## Milestones

- [x] **M0 — Toolchain**: Elixir/OTP via asdf, Phoenix scaffold, Postgres docker. `mix test` green.
- [x] **M1 — Elo engine**: pure module, K=32, ties, byes, tallies. 14 tests green.
- [x] **M2 — start.gg client**: rate limiter, backoff, Bypass tests + live smoke.
- [x] **M3 — Crawler**: window-walk, seen-set, error isolation, chronological Elo. Live smoke.
- [x] **M4 — Search + lookup**: index-first search, live participant-scan fallback, ranked results.
- [x] **M5 — LiveViews** (2026-08-14, 118 tests):
  - `KusaData.Stats` (W/L, win rate, streaks, H2H over DB sets),
  - `KusaData.Cache` (Redix, TTL, graceful bypass) + `KusaData.SetDetails`
    (on-demand games/stages/characters from start.gg, Redis-cached) + pure
    `SetDetails.Parse`,
  - `KusaData.Rankings` context + leaderboard LiveView,
  - `KusaData.Players` context + player LiveView (stats, set history,
    character/stage breakdown),
  - VS Mode (two-panel compare + H2H), player search results page,
  - Tournament LiveView (roster + seed finder with URL normalizer),
  - component kit (`KusaDataWeb.Kit`), design tokens, **daisyUI removed**,
    theme toggle removed (light paper palette only).
- [ ] **M6 — Polish + Fly.io deploy**: a11y audit (contrast pass done — tokens all meet
      WCAG AA; visual/screenshot review pending a human eye), responsive check, Fly deploy
      config generated (`Dockerfile`, `fly.toml`, release overlay) — deployment itself needs
      `flyctl` + secrets.
- [x] **Migration (2026-08-14)**: SvelteKit app deleted, Elixir app moved to repo root,
      `ACCESS_TOKEN` wired into client + runtime config, Melee videogame_id fixed, dev DB wiped
      and re-crawled live (10 tournaments / 103 sets / 59 rated players).

## Next Steps (current plan)

1. **M6 — Polish**: `mix precommit` + credo green (currently 118 tests), a11y audit
   (contrast, focus, aria), responsive pass (mobile header, table overflow), manual browser
   screenshots against the UI Standard.
2. **Crawl scheduling** (deferred): periodic crawl (e.g. daily) so rankings stay fresh —
   currently manual via `mix run -e 'KusaData.Crawl.run(1)'`.
3. **Fly.io deploy**: Dockerfile + fly.toml, env vars (`DATABASE_URL`, `SECRET_KEY_BASE`,
   `PHX_HOST`, `ACCESS_TOKEN`, `REDIS_URL`), `mix assets.deploy`, deployed smoke run.

## Operating rules for agents

- Read this file. The SvelteKit app is deleted; do not look for or reference it.
- One failing test per feature first; run `mix test` after every meaningful step.
- Quality gates on every change: `mix precommit` (or at minimum `mix test` + `mix format
  --check-formatted`) and `mix credo`. Never claim "done" without green test output quoted.
- Integration features additionally prove against the live start.gg API (env token) with one
  bounded smoke run.
- UI changes: screenshot and check against the UI Standard list before reporting done.
- Report format: what changed, test command + output (green), any live-API smoke results.

---

## Phoenix / Elixir engineering guidelines

Generated by `phx.new`; kept here as hard rules for agents.

### Project guidelines

- Use `mix precommit` when done with all changes and fix any pending issues.
- Use the bundled `Req` library for HTTP requests. **Avoid** `:httpoison`, `:tesla`, `:httpc`.

### Phoenix v1.8 guidelines

- **Always** begin LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner
  content. `MyAppWeb.Layouts` is aliased in the app's `web.ex`, so no extra alias is needed.
- Any `current_scope` assign errors: you failed to follow the Authenticated Routes guidelines or
  failed to pass `current_scope` to `<Layouts.app>` — fix by moving routes to the proper
  `live_session` and passing `current_scope`.
- Phoenix v1.8 moved `<.flash_group>` to the `Layouts` module. **Forbidden** to call
  `<.flash_group>` outside `layouts.ex`.
- Out of the box, `core_components.ex` imports `<.icon name="hero-x-mark" class="w-5 h-5"/>`.
  **Always** use `<.icon>` for icons, never `Heroicons` modules directly.
- **Always** use the imported `<.input>` component for form inputs. If you override its class
  attribute, defaults are not inherited — your custom classes must fully style the input.

### JS and CSS guidelines

- Use Tailwind classes and custom CSS for polished, responsive interfaces.
- Tailwind v4 needs no `tailwind.config.js`; keep the import syntax in `app.css`:

  ```css
  @import "tailwindcss" source(none);
  @source "../css";
  @source "../js";
  @source "../../lib/my_app_web";
  ```

- **Always use and maintain this import syntax** for projects generated with `phx.new`.
- **Never** use `@apply` when writing raw CSS.
- **Never use daisyUI** — write your own Tailwind-based components (this repo's UI Standard).
- Out of the box only `app.js` and `app.css` bundles are supported: no external vendor `<script>`
  or `<link>` in layouts; import vendor deps into `app.js`/`app.css` instead.
- **Never** write inline `<script>` tags within templates (use colocated hooks — see below).

### UI/UX & design guidelines

- Produce world-class UI: clean typography, spacing, layout balance; subtle micro-interactions
  (hover effects, smooth transitions); loading states; smooth page transitions.

### Elixir guidelines

- Elixir lists do not support index access via `list[i]` — use `Enum.at/3` or pattern matching.
- Variables are immutable but rebindable; for `if`/`case`/`cond` you **must** bind the result:

  ```elixir
  # INVALID: rebinding inside `if`, result never assigned
  if connected?(socket) do
    socket = assign(socket, :val, val)
  end
  # VALID
  socket =
    if connected?(socket) do
      assign(socket, :val, val)
    end
  ```

- **Never** nest multiple modules in the same file (cyclic dependency / compile errors).
- **Never** use map access syntax (`changeset[:field]`) on structs — access fields directly or use
  `Ecto.Changeset.get_field/2`.
- Elixir's stdlib covers date/time needs. **Never** install extra deps unless asked (or
  `date_time_parser` for parsing).
- Don't use `String.to_atom/1` on user input (memory leak risk).
- Predicate function names should not start with `is_` and should end in `?`.
- OTP primitives like `DynamicSupervisor` and `Registry` require names in the child spec.
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure (usually
  `timeout: :infinity`).

### Mix guidelines

- Read the docs before using tasks (`mix help task_name`).
- Debug test failures with `mix test test/my_test.exs` or `mix test --failed`.
- `mix deps.clean --all` is almost never needed — avoid.

### Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests (guaranteed cleanup).
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests. To wait for a process:
  `ref = Process.monitor(pid)` then `assert_receive {:DOWN, ^ref, :process, ^pid, :normal}`.
  To synchronize before the next call, use `_ = :sys.get_state/1`.

### Phoenix guidelines

- Router `scope` blocks include an optional alias prefixed to all routes in the scope — mindful
  of this when creating routes to avoid duplicate module prefixes.
- You never need to create your own `alias` for route definitions; the scope provides it.
- `Phoenix.View` is not needed or included — don't use it.

### Ecto guidelines

- **Always** preload associations in queries when they'll be accessed in templates.
- `import Ecto.Query` in seeds/scripts when writing queries.
- Schema fields use `:string` type, even for `:text` columns.
- `Ecto.Changeset.validate_number/2` **does not support** `:allow_nil` — it's never needed
  (validations only run for present, non-nil changes).
- **Always** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields.
- Fields set programmatically (e.g. `user_id`) must not be in `cast` — set them explicitly.
- **Always** invoke `mix ecto.gen.migration name_using_underscores` for migrations.

### Phoenix HTML (HEEx) guidelines

- Templates **always** use `~H` or `.heex` files (never `~E`).
- **Always** use `Phoenix.Component.form/1` + `inputs_for/1` and `to_form/2` to build forms.
- **Always** add unique DOM IDs to key elements (forms, buttons, etc.) — used in tests.
- App-wide template imports go in the app's `web.ex` `html_helpers` block.
- Elixir supports `if/else` but **not** `else if`/`elsif` — use `cond` or `case`.
- HEEx: literal `{`/`}` in `<pre>`/`<code>` requires `phx-no-curly-interpolation` on the parent tag.
- HEEx class attrs with multiple values **must** use list syntax `[...]`, wrapping `if` in `{}`:

  ```heex
  <a class={[
    "px-2 text-white",
    @some_flag && "py-5",
    if(@other_condition, do: "border-red-500", else: "border-blue-100")
  ]}>Text</a>
  ```

- **Never** use `<% Enum.each %>` — always `<%= for item <- @collection do %>`.
- HEEx HTML comments use `<%!-- comment --%>`.
- Interpolate with `{...}` inside tag attributes; `<%= ... %>` only within tag bodies. Block
  constructs (`if`, `cond`, `case`, `for`) in tag bodies must use `<%= ... %>`.

### Phoenix LiveView guidelines

- **Never** use deprecated `live_redirect`/`live_patch` — use `<.link navigate={href}>` and
  `<.link patch={href}>` in templates, `push_navigate`/`push_patch` in LiveViews.
- **Avoid LiveComponents** unless a strong, specific need exists.
- LiveViews named like `AppWeb.WeatherLive` with `Live` suffix.

#### LiveView streams

- **Always** use streams for collections instead of plain list assigns:
  - append: `stream(socket, :messages, [new_msg])`
  - reset (filtering): `stream(socket, :messages, [new_msg], reset: true)`
  - prepend: `stream(socket, :messages, [new_msg], at: -1)`
  - delete: `stream_delete(socket, :messages, msg)`
- Template: `phx-update="stream"` on the parent with a DOM id, iterate `@streams.messages`, use
  the stream id as each child's DOM id:

  ```heex
  <div id="messages" phx-update="stream">
    <div :for={{id, msg} <- @streams.messages} id={id}>
      {msg.text}
    </div>
  </div>
  ```

- Streams are not enumerable — to filter/prune, refetch and re-stream with `reset: true`.
- Streams don't support counting or empty states — track counts in a separate assign; empty state
  via `class="hidden only:block"` on a sibling div of the stream comprehension.
- When an assign changes content inside streamed items, re-stream the items along with the assign.

#### LiveView JavaScript interop

- `phx-hook="MyHook"` hooks managing their own DOM **must** also set `phx-update="ignore"` and an
  unique DOM id.
- **Never** write raw `<script>` tags in HEEx — use colocated hooks
  (`:type={Phoenix.LiveView.ColocatedHook}`, names start with `.`, auto-bundled into app.js)
  or external hooks in `assets/js/` passed to the `LiveSocket` constructor.
- Push events: `socket = push_event(socket, "my_event", %{...})` (rebind); receive in JS with
  `this.handleEvent`; reply via `{:reply, %{...}, socket}` in `handle_event`.

#### LiveView tests

- Use `Phoenix.LiveViewTest` and `LazyHTML` for assertions.
- Split major test cases into small, isolated files; start simple (content exists), add interactions.
- **Always** reference the key element IDs you added in templates in tests.
- **Never** test raw HTML — use `element/2`, `has_element?/2`, etc.
- Prefer asserting on key elements over text content (which changes).
- Forms are driven by `render_submit/2` and `render_change/2`.
- `<.form>` output may differ from your mental model — test against actual output structure.
- For selector failures, debug with `LazyHTML.from_fragment/1` + `LazyHTML.filter/2`.

### Form handling

- Create forms from params: `to_form(params)` (string keys) or `to_form(user_params, as: :user)`.
- Create forms from changesets: `%MyApp.Users.User{} |> Ecto.Changeset.change() |> to_form()`.
- In templates: `<.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">`
  with `<.input field={@form[:field]} type="text" />`; always give forms unique DOM IDs.
- **Never** access the changeset in templates — always drive UI from a `to_form/2` assign.
- **Never** use `<.form let={f} ...>` — use `<.form for={@form} ...>`.
