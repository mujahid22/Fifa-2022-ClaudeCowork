-- =============================================================
-- Qatar 2022 Dashboard — every query that produced an embedded number
-- Database: Fifa2024 (PostgreSQL 18.3)
-- Run order matches the dashboard top-to-bottom.
-- =============================================================

-- -------------------------------------------------------------
-- 0. Inventory
-- -------------------------------------------------------------

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog','information_schema')
ORDER BY table_schema, table_name;

SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('world_cups','wc2022_groups','wc2022_squads',
                     'wc2022_matches','world_cup_matches','international_matches')
ORDER BY table_name, ordinal_position;

SELECT 'world_cups'            AS t, COUNT(*) AS n, MIN(year)::text AS min_y, MAX(year)::text AS max_y FROM world_cups
UNION ALL SELECT 'world_cup_matches',     COUNT(*), MIN(year)::text, MAX(year)::text FROM world_cup_matches
UNION ALL SELECT 'wc2022_matches',        COUNT(*), MIN(year)::text, MAX(year)::text FROM wc2022_matches
UNION ALL SELECT 'wc2022_groups',         COUNT(*), NULL, NULL FROM wc2022_groups
UNION ALL SELECT 'wc2022_squads',         COUNT(*), NULL, NULL FROM wc2022_squads
UNION ALL SELECT 'international_matches', COUNT(*),
                                          EXTRACT(YEAR FROM MIN(match_date))::text,
                                          EXTRACT(YEAR FROM MAX(match_date))::text
                                   FROM international_matches;

-- -------------------------------------------------------------
-- 1. All-time titles, finals, semifinal appearances
-- -------------------------------------------------------------
WITH norm AS (
  SELECT year,
    CASE WHEN winner='Germany FR'     THEN 'Germany' ELSE winner     END AS winner,
    CASE WHEN runners_up='Germany FR' THEN 'Germany' ELSE runners_up END AS runners_up,
    CASE WHEN third='Germany FR'      THEN 'Germany' ELSE third      END AS third,
    CASE WHEN fourth='Germany FR'     THEN 'Germany' ELSE fourth     END AS fourth
  FROM world_cups WHERE winner IS NOT NULL
),
rolled AS (
  SELECT winner    AS team, 1 AS titles, 1 AS final, 1 AS top4 FROM norm
  UNION ALL SELECT runners_up, 0, 1, 1 FROM norm
  UNION ALL SELECT third,      0, 0, 1 FROM norm
  UNION ALL SELECT fourth,     0, 0, 1 FROM norm
)
SELECT team, SUM(titles) AS titles, SUM(final) AS finals_appearances, SUM(top4) AS top4
FROM rolled GROUP BY team
ORDER BY titles DESC, finals_appearances DESC, top4 DESC;

-- -------------------------------------------------------------
-- 2. Goals trend per tournament (1930-2018)
-- -------------------------------------------------------------
SELECT year, host_country, qualified_teams, matches_played, goals_scored,
       ROUND(goals_scored::numeric / NULLIF(matches_played,0), 2) AS goals_per_match
FROM world_cups WHERE goals_scored IS NOT NULL ORDER BY year;

-- -------------------------------------------------------------
-- 3. Host advantage
-- -------------------------------------------------------------
WITH n AS (
  SELECT year, host_country,
    CASE WHEN winner='Germany FR'     THEN 'Germany' ELSE winner     END AS winner,
    CASE WHEN runners_up='Germany FR' THEN 'Germany' ELSE runners_up END AS runners_up,
    CASE WHEN third='Germany FR'      THEN 'Germany' ELSE third      END AS third,
    CASE WHEN fourth='Germany FR'     THEN 'Germany' ELSE fourth     END AS fourth
  FROM world_cups WHERE winner IS NOT NULL
)
SELECT year, host_country,
  CASE WHEN host_country = winner            THEN 'Won'
       WHEN host_country = runners_up        THEN 'Final'
       WHEN host_country IN (third, fourth)  THEN 'Semifinal'
       ELSE 'Did not reach top 4'
  END AS host_finish
FROM n ORDER BY year;

-- -------------------------------------------------------------
-- 4. Team match-level metrics (1930-2018)
-- -------------------------------------------------------------
WITH long AS (
  SELECT year, home_team AS team, home_goals AS gf, away_goals AS ga,
         CASE WHEN home_goals>away_goals THEN 'W'
              WHEN home_goals=away_goals THEN 'D' ELSE 'L' END AS r
  FROM world_cup_matches WHERE home_goals IS NOT NULL
  UNION ALL
  SELECT year, away_team, away_goals, home_goals,
         CASE WHEN away_goals>home_goals THEN 'W'
              WHEN away_goals=home_goals THEN 'D' ELSE 'L' END
  FROM world_cup_matches WHERE home_goals IS NOT NULL
),
agg AS (
  SELECT CASE WHEN team='Germany FR' THEN 'Germany' ELSE team END AS team,
         COUNT(*) AS matches,
         SUM(CASE WHEN r='W' THEN 1 ELSE 0 END) AS wins,
         SUM(CASE WHEN r='D' THEN 1 ELSE 0 END) AS draws,
         SUM(CASE WHEN r='L' THEN 1 ELSE 0 END) AS losses,
         SUM(gf) AS gf, SUM(ga) AS ga
  FROM long GROUP BY 1
)
SELECT team, matches, wins, draws, losses, gf, ga, gf-ga AS gd,
       ROUND(100.0*wins/NULLIF(matches,0),1) AS win_pct
FROM agg ORDER BY matches DESC LIMIT 30;

-- -------------------------------------------------------------
-- 5. Biggest wins ever
-- -------------------------------------------------------------
SELECT year, stage, home_team, home_goals, away_goals, away_team,
       ABS(home_goals-away_goals) AS margin
FROM world_cup_matches WHERE home_goals IS NOT NULL
ORDER BY margin DESC, (home_goals+away_goals) DESC LIMIT 10;

-- -------------------------------------------------------------
-- 6. Knockout drama (extra time, penalties, golden goal)
-- -------------------------------------------------------------
SELECT year, stage, home_team, home_goals, away_goals, away_team, win_conditions
FROM world_cup_matches
WHERE win_conditions IS NOT NULL AND win_conditions <> ''
ORDER BY year DESC, id;

-- -------------------------------------------------------------
-- 7. Most-played WC head-to-heads
-- -------------------------------------------------------------
WITH p AS (
  SELECT LEAST(home_team, away_team) AS a, GREATEST(home_team, away_team) AS b
  FROM world_cup_matches WHERE home_goals IS NOT NULL
)
SELECT a, b, COUNT(*) AS meetings FROM p GROUP BY a, b ORDER BY meetings DESC LIMIT 12;

-- -------------------------------------------------------------
-- 8. Single-tournament team scoring runs
-- -------------------------------------------------------------
WITH long AS (
  SELECT year, home_team AS team, home_goals AS gf FROM world_cup_matches WHERE home_goals IS NOT NULL
  UNION ALL
  SELECT year, away_team, away_goals FROM world_cup_matches WHERE home_goals IS NOT NULL
)
SELECT year, CASE WHEN team='Germany FR' THEN 'Germany' ELSE team END AS team, SUM(gf) AS goals
FROM long GROUP BY year, team ORDER BY goals DESC LIMIT 12;

-- =============================================================
-- 2022 SECTION
-- =============================================================

-- 9. Group draw + average FIFA rank per group
SELECT group_letter,
       ROUND(AVG(fifa_ranking)::numeric, 1) AS avg_rank,
       MIN(fifa_ranking) AS top_rank,
       MAX(fifa_ranking) AS weakest_rank,
       STRING_AGG(team || ' (' || fifa_ranking || ')', ', ' ORDER BY fifa_ranking) AS teams
FROM wc2022_groups GROUP BY group_letter ORDER BY avg_rank;

-- 10. Squad summary by team (2022)
SELECT team, COUNT(*) AS players,
       ROUND(AVG(age)::numeric, 1) AS avg_age,
       MIN(age) AS min_age, MAX(age) AS max_age,
       SUM(CASE WHEN position='Goalkeeper' THEN 1 ELSE 0 END) AS gk,
       SUM(CASE WHEN position='Defender'   THEN 1 ELSE 0 END) AS def,
       SUM(CASE WHEN position='Midfielder' THEN 1 ELSE 0 END) AS mid,
       SUM(CASE WHEN position='Forward'    THEN 1 ELSE 0 END) AS fwd,
       SUM(caps) AS total_caps, SUM(goals) AS total_int_goals
FROM wc2022_squads GROUP BY team ORDER BY avg_age DESC;

-- 11. League representation (2022)
SELECT league, COUNT(*) AS players,
       COUNT(DISTINCT team) AS national_teams_supplying,
       ROUND(AVG(age)::numeric, 1) AS avg_age, SUM(goals) AS total_int_goals
FROM wc2022_squads GROUP BY league ORDER BY players DESC;

-- 12. Top-5 most prolific players per team
WITH ranked AS (
  SELECT team, player, position, age, caps, goals, wc_goals, league, club,
         ROW_NUMBER() OVER (PARTITION BY team ORDER BY goals DESC, caps DESC) AS rk
  FROM wc2022_squads
)
SELECT team, player, position, age, caps, goals, wc_goals, league, club
FROM ranked WHERE rk <= 5 ORDER BY team, rk;

-- 13. Captains
SELECT team, REPLACE(player, ' (captain)', '') AS captain, position, age, club, league
FROM wc2022_squads WHERE player ILIKE '%(captain)%' ORDER BY team;

-- 14. Top clubs supplying squad players
SELECT club, league, COUNT(*) AS players, COUNT(DISTINCT team) AS countries
FROM wc2022_squads GROUP BY club, league ORDER BY players DESC LIMIT 20;

-- 15. Foreign-based vs domestic-based per team
SELECT team,
       SUM(CASE WHEN team = league THEN 1 ELSE 0 END) AS domestic_league,
       SUM(CASE WHEN team <> league THEN 1 ELSE 0 END) AS foreign_league,
       ROUND(100.0*SUM(CASE WHEN team <> league THEN 1 ELSE 0 END)/COUNT(*), 1) AS foreign_pct
FROM wc2022_squads GROUP BY team ORDER BY foreign_pct DESC;

-- 16. Form heading into Qatar (2018-2022) — qualified teams only
WITH teams AS (SELECT DISTINCT team FROM wc2022_groups),
long AS (
  SELECT home_team AS team,
         CASE WHEN home_goals > away_goals THEN 1 ELSE 0 END AS w,
         CASE WHEN home_goals = away_goals THEN 1 ELSE 0 END AS d,
         home_goals AS gf, away_goals AS ga
  FROM international_matches
  WHERE EXTRACT(YEAR FROM match_date) BETWEEN 2018 AND 2022 AND home_goals IS NOT NULL
  UNION ALL
  SELECT away_team,
         CASE WHEN away_goals > home_goals THEN 1 ELSE 0 END,
         CASE WHEN home_goals = away_goals THEN 1 ELSE 0 END,
         away_goals, home_goals
  FROM international_matches
  WHERE EXTRACT(YEAR FROM match_date) BETWEEN 2018 AND 2022 AND home_goals IS NOT NULL
)
SELECT l.team, COUNT(*) AS played, SUM(w) AS wins, SUM(d) AS draws,
       COUNT(*) - SUM(w) - SUM(d) AS losses,
       SUM(gf) AS gf, SUM(ga) AS ga,
       ROUND(100.0*SUM(w)::numeric/COUNT(*), 1) AS win_pct
FROM long l JOIN teams t ON t.team = l.team
GROUP BY l.team ORDER BY win_pct DESC;

-- 17. Top scorers across the squad pool
SELECT player, team, position, age, club, league, caps, goals, wc_goals
FROM wc2022_squads ORDER BY goals DESC, caps DESC LIMIT 25;

-- 18. Age distribution buckets
SELECT age_band, COUNT(*) AS players
FROM (
  SELECT CASE
    WHEN age < 21 THEN '<21' WHEN age BETWEEN 21 AND 24 THEN '21-24'
    WHEN age BETWEEN 25 AND 28 THEN '25-28' WHEN age BETWEEN 29 AND 32 THEN '29-32'
    ELSE '33+' END AS age_band
  FROM wc2022_squads
) s
GROUP BY age_band
ORDER BY CASE age_band WHEN '<21' THEN 1 WHEN '21-24' THEN 2 WHEN '25-28' THEN 3 WHEN '29-32' THEN 4 ELSE 5 END;

-- 19. Verification — sanity-check podium counts
WITH n AS (
  SELECT
    CASE WHEN winner='Germany FR'     THEN 'Germany' ELSE winner     END AS w,
    CASE WHEN runners_up='Germany FR' THEN 'Germany' ELSE runners_up END AS r,
    CASE WHEN third='Germany FR'      THEN 'Germany' ELSE third      END AS t3,
    CASE WHEN fourth='Germany FR'     THEN 'Germany' ELSE fourth     END AS t4
  FROM world_cups WHERE winner IS NOT NULL
)
SELECT 'Brazil titles' AS k, (SELECT COUNT(*) FROM n WHERE w='Brazil') AS v
UNION ALL SELECT 'Brazil top4',  (SELECT COUNT(*) FROM n WHERE 'Brazil'  IN (w,r,t3,t4))
UNION ALL SELECT 'Germany titles', (SELECT COUNT(*) FROM n WHERE w='Germany')
UNION ALL SELECT 'Germany top4',   (SELECT COUNT(*) FROM n WHERE 'Germany' IN (w,r,t3,t4))
UNION ALL SELECT 'Editions w/ results', (SELECT COUNT(*) FROM n);

-- Expected from production data:
--   Brazil titles  = 5,  Brazil top4  = 11
--   Germany titles = 4,  Germany top4 = 13
--   Editions = 21
