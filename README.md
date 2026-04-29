# Qatar 2022 Dashboard

An interactive single-file dashboard summarising the FIFA 2022 World Cup — team-by-team standings, the knockout bracket, top scorers, awards, and a per-team drill-down with squad, coach, captain, journey and key achievements. Data is pulled from a `Fifa2024` Postgres database and combined with the public tournament record.

## What's in this repo

```
.
├── README.md                          ← you are here
├── SKILL.md                           ← reusable skill: turn any tournament DB into a dashboard
├── dashboards/
│   └── qatar-2022-dashboard.html      ← the deliverable, open in any browser
├── docs/
│   └── data-model.md                  ← star-schema design + Mermaid ER diagram
├── sql/
│   └── queries.sql                    ← every SQL query that produced the embedded numbers
├── push-to-github.ps1                 ← Windows helper that pushes this folder to a new GitHub repo
└── .gitignore
```

## Open the dashboard

`dashboards/qatar-2022-dashboard.html` is fully self-contained — open it in any browser. It needs internet only to load Chart.js from a public CDN.

## Reuse the skill

Drop `SKILL.md` into a Cowork or Claude Code skills folder. It triggers when a user asks for a tournament dashboard from a relational database and walks through inventory → star-schema model → SQL aggregations → single-file HTML delivery.

## Source data

- **From the database** (`Fifa2024` Postgres): all 32 squads, captains, ages, clubs, leagues, FIFA rankings, and the schedule of fixtures.
- **From the public match record**: actual scores, group-stage standings, knockout outcomes, top scorers and individual awards. The `wc2022_matches` table in the database has the schedule but no goals.

No FIFA logos or licensed player photos are used — countries are shown as Unicode flag emoji and team-color CSS gradients.

## How the dashboard was built

1. Inventoried the seven tables in `Fifa2024`.
2. Designed a star schema (see `docs/data-model.md`) that conforms `Germany FR` into `Germany` and gives every chart a one-row-per-team-per-match view to read from.
3. Ran 19 aggregation queries (see `sql/queries.sql`) to produce the per-team summaries, group standings, top scorers, etc.
4. Embedded every dataset as inline JSON in a single HTML file. Chart.js for charts, inline SVG for trophies/medals/world map, Unicode emoji for flags.
5. Verified one number against the source DB before delivering (Brazil 5 titles / 11 top-4s; Germany 4 / 13).

## Live URL via GitHub Pages

Once pushed, enable GitHub Pages on this repo:

1. Open **Settings → Pages**.
2. Under **Source**, choose **Deploy from a branch**, select `main` and `/ (root)`.
3. Wait ~30 seconds; the dashboard is live at:
   `https://mujahid22.github.io/Fifa-2022-ClaudeCowork/dashboards/qatar-2022-dashboard.html`

Share that URL with anyone — no install needed.

## License

Code in this repo is yours to reuse. Tournament data is public record.
