---
name: postgres-to-tournament-dashboard
description: Turn a relational sports / tournament database into a polished, single-file interactive HTML dashboard. Use when a user asks for a tournament summary, league dashboard, season recap, or "make a dashboard from this database" with team/player/match data. Covers data exploration, star-schema modeling, KPI computation, and producing a self-contained HTML page with team filter, group standings, knockout bracket, top scorers, awards, and per-team drill-down.
---

# Postgres → Tournament Dashboard

A reusable recipe for building tournament dashboards from a relational database. Produced as a single self-contained HTML file the user can email, drop on Netlify / GitHub Pages, or open straight from their machine.

## When to use this skill

Trigger when the user asks any of:

- "Build a dashboard for the {tournament/league/season}"
- "Summarise the teams, groups and standings from this database"
- "Make me an interactive dashboard with a team filter"
- "Visualise this Postgres data" (and the data is sports / tournament-shaped)

Don't use this skill for ad-hoc one-off charts, exploratory notebooks, or non-tournament dashboards (sales pipeline, KPI dashboards, etc.) — those belong elsewhere.

## Process

### 1. Inventory the database first

Before designing anything, list tables and look at one or two sample rows from each. Use these queries (template):

```sql
-- list tables
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog','information_schema')
ORDER BY table_schema, table_name;

-- list columns + types for a target schema
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

-- row counts and date ranges
SELECT 'tablename' AS t, COUNT(*) AS n FROM tablename;
```

Note **what's missing**. In sports DBs, the most common gap is "schedule but no scores yet" or "results table missing the current edition." Surface this to the user up front so the user knows what comes from the DB and what comes from public records.

### 2. Design a star schema

Every tournament DB collapses cleanly into one star schema:

| Layer       | Tables                                              | Notes                                                                 |
|-------------|-----------------------------------------------------|-----------------------------------------------------------------------|
| Dimensions  | `dim_country`, `dim_date`, `dim_tournament`, `dim_stage`, `dim_player`, `dim_club` | Conform `dim_country` so `Germany FR` rolls into `Germany`. |
| Facts       | `fact_match` (one row per match), `fact_squad` (one row per player-tournament), `fact_world_cup` (one row per edition), `fact_outcome` (winner/runner-up/3rd/4th) | |
| Bridge view | `vw_team_match` (one row per team-per-match)         | Removes home/away unions in every downstream query.                  |

Document this in a separate `data-model.md` file — Mermaid ER diagram + a transform table mapping source tables → fact/dim layout + key transformations (e.g. parsing `(captain)` out of player names into `is_captain`).

### 3. Compute the dashboard's data once, in SQL

Write 8-12 aggregation queries — one per dashboard tile. Always include:

- **Champions / podium** for the tournament edition
- **Group standings** (`team`, `points`, `W/D/L`, `GF/GA`, `advanced` flag)
- **Knockout matches by round** (`R16`, `QF`, `SF`, `Final`, with penalty/ET notes)
- **Top scorers** (player, team, goals, golden-boot/ball flags)
- **Per-team squad summary** (count, avg age, GK/DEF/MID/FWD breakdown, foreign-based %)
- **Top-N players per team** (window function: `ROW_NUMBER() OVER (PARTITION BY team ORDER BY goals DESC, caps DESC)`)
- **Captains** (filtered or parsed)
- **League / club representation**

Result: results stay small, queries are independent, and the HTML can embed every dataset inline as JSON. Don't proxy the DB at runtime — bake the numbers in so the file is shareable as a single artifact.

### 4. Build the HTML

Single self-contained file. No backend. Hard rules:

- **Allowed CDNs only:** Chart.js, Grid.js, Mermaid (when running inside a Cowork artifact). When delivering as a downloadable file, the same CDNs are fine — they're public.
- **Light mode design.** Add `:root { color-scheme: light }`.
- **Tournament identity, not licensed assets.** Use Unicode flag emojis for countries; team-color CSS gradients for hero banners; inline SVG for trophy / ball / medal icons. **Never** include FIFA / official mascot / club logos / licensed player photos — they're trademarked, and the artifact sandbox blocks fetching them anyway.
- **Team filter is mandatory.** A `<select>` at the top toggles between an "all teams" overview and a per-team drill-down view. Drill-down hero uses the team's primary/secondary colors as a gradient.
- **Sections:** champions podium → KPI strip → awards → group standings → knockout bracket → top scorers → defining storylines → squad/league charts → team filter → team-detail (hero, stats, journey, star players, achievements, country pin on map).
- **Tone:** muted gold + maroon palette for World Cup style; team colors override on drill-down.

### 5. Verify before delivering

Always verify at least one number with a SQL query against the source DB. Pick something countable (titles, qualified teams, total players). If a number doesn't reconcile, fix it before showing.

### 6. Deliver

Save the HTML to the outputs folder. In the chat reply:

- One-paragraph summary of what's in the dashboard.
- A `computer://` link to open it.
- Note any data caveat (e.g. "results compiled from public records since the DB only has the schedule").

## Common pitfalls

- **Treating the DB output as ground truth for everything.** Always check whether the current edition's results are populated.
- **Over-using bullets in the chat reply.** The deliverable is the HTML, not the explanation.
- **Trying to fetch flag SVGs / official logos.** Use Unicode emoji and inline SVG. The sandbox blocks external image hosts.
- **Building a reactive Postgres-querying dashboard.** Slow, breaks when the DB sleeps, blocks easy sharing. Always bake the data in.
- **Overly long select dropdown.** Sort teams alphabetically, prefix with the flag emoji, keep one option for the overview.

## File outputs

- `dashboards/{tournament-slug}-dashboard.html` — the deliverable
- `docs/data-model.md` — the model, separate so it can be reviewed without scrolling through HTML
- `sql/queries.sql` — every query that produced the embedded numbers, in execution order, so the dashboard is reproducible

## Reference implementation

The Qatar 2022 dashboard in this repo is the canonical example. It pulls 32 team summaries, group standings, the full knockout bracket, top-5 players per team, and per-team achievements out of a single Postgres database, then embeds every dataset as inline JSON in one HTML file with a team-filter dropdown.
