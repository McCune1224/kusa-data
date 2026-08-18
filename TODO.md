# TODO — Future Feature Ideas

Not planned for today. A backlog of ideas to pick from later, roughly ordered
within each section by impact vs. effort.

---

## Discovery & Search

- [x] Browse **past tournaments** — date range / month picker, search by name,
      city, or venue, plus "results-only" filtering (tournaments with finished brackets).
- [x] Hot search for tournament names while typing (not just ZIP/postal proximity).
- [x] Flexible URL / slug pasting — accept any start.gg URL shape
      (`start.gg/tournament/x`, `start.gg/tournament/x/event/y/...`), unfurl in place.
- [x] Save/Bookmark tournaments, and get "your tournaments" on the home page.
- [x] Calendar / iCal export for upcoming events ("Add to calendar").
- [x] Region pages — browse by country/state lists instead of only a radius.

---

## Multi-Game Support

- [x] Show **ALL events** at a tournament, not just Melee (filter toggle per game).
- [x] Per-game landing/tag pages (Melee, Ultimate, Project M) once non-Melee data lands.
- [x] Unified player page that can show stats across every game they entered.

---

## Bracket & Tournament Analytics

- [x] Seeding accuracy analysis — compare final placement vs. seed, flag upsets.
- [x] "Upset of the weekend" — biggest seed-vs-placement swings, per tournament or week.
- [x] Per-tournament stats recap — entrant count, DQ rate, match count, avg sets per entrant.
- [x] Per-event standings view with W/L breakdown for each entrant (sets won/lost).
- [x] Auto-detect weird brackets — changed seeds, reseeds, unseeded top finishers.
- [x] **Export tools** — CSV/JSON export of seeds, results, and head-to-head data.

---

## Player Features (Braacket-inspired)

- [x] **Power rankings** for a region/league:
      - Elo / Glicko-2 / TrueSkill™ / point-based systems, ELO-style "1500 start".
      - Weight recent months downward (“season” rankings).
      - Minimum-tournaments-played thresholds.
      - Monthly/season/time-window rankings, not just all-time.
- [x] Compare two players side-by-side (record, per-event finishes, trend).
- [x] Full player match history page (all results, filterable by event/opponent/date).
- [x] Player head-to-head history table vs any opponent.
- [x] Player trend chart — placements and win-rate over time / vs. previous year.
- [x] Character matchup grids (who beats who, per character) if game-level data allows.

---

## Broader Product Ideas

- [x] "This week in Melee" digest — top upsets, biggest events, player spotlights.
- [x] Notifications: watch a player/tournament and get pinged on result changes
      (email/web/niche Telegram/Discord).
- [x] League concept — group linked tournaments into a season and show standings,
      mirroring how Braacket leagues work.
- [x] RSS/JSON feed of past and upcoming events for local scenes.
- [x] Offline/PWA read of previously viewed brackets and player pages.
- [x] Dark-only is intentional; consider an optional light theme switch.

---

## Braacket behaviors worth stealing wholesale

- [x] Player **settings + linking** — de-duplicate tags/prefixes across tournaments
      so one tag has a single canonical profile.
- [x] Auto-generated **player cards** (total sets, best placements, recent form).
- [x] Per-ranking **eligibility rules** (e.g. "requires 3 tournaments").
- [x] One-click **import a tournament from start.gg into a league** and auto-link
      its players against existing league members.