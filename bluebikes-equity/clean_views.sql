-- Who Does Bluebikes Actually Serve?
-- Cleaning views (MySQL 8). Run after schema.sql and load.sql.
--
-- The base tables are never edited. Every filter lives in a view here,
-- so the raw data stays intact and each cleaning step is visible for the writeup.
-- Query the v_ views instead of the base tables unless you have a reason not to.

USE bluebikes;

-- ---------------------------------------------------------------------------
-- v_station_active
-- Real public stations that had trips in Jul to Sep 2026.
-- Excludes:
--   X32999  Bluebikes depot, not a real station
--   BCBS01  corporate station in Hingham
--   station_cohort = 'inactive'  14 stations with no 2026 trips at all
--     (7 in Boston). Leaving them in would count unused stations as
--     serving a neighborhood.
-- Result: 620 stations, 355 in Boston.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_station_active AS
SELECT s.*
FROM station s
WHERE s.station_id NOT IN ('X32999', 'BCBS01')
  AND s.station_cohort <> 'inactive';


-- ---------------------------------------------------------------------------
-- v_trip_clean
-- Trips where both the start and end station are in v_station_active,
-- plus derived columns so queries don't each recompute them.
--   is_round_trip     1 if the trip starts and ends at the same station.
--                     Keep for ridership counts, exclude for trip length.
--   distance_bucket   straight-line distance band; 'round trip' for round trips
--                     so they can't sneak into the under-1km bucket
--   distance_bucket_order  sort key for distance_bucket (0 = round trip)
--   duration_min      trip length in minutes
--   start_hour        0 to 23, Boston local time
--   is_weekday        1 = Monday to Friday (holidays not removed)
--   start_/end_ municipality and neighborhood_id (neighborhood is NULL outside Boston)
--   bike_type_name, rider_type_name  from the lookup tables
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_trip_clean AS
SELECT t.ride_id,
       t.start_station_id,
       t.end_station_id,
       t.started_at,
       t.ended_at,
       t.duration_sec,
       ROUND(t.duration_sec / 60, 1)                     AS duration_min,
       t.distance_m,
       (t.start_station_id = t.end_station_id)           AS is_round_trip,
       CASE
           WHEN t.start_station_id = t.end_station_id THEN 'round trip'
           WHEN t.distance_m < 1000 THEN 'under 1km'
           WHEN t.distance_m < 2000 THEN '1 to 2km'
           WHEN t.distance_m < 3000 THEN '2 to 3km'
           WHEN t.distance_m < 5000 THEN '3 to 5km'
           ELSE '5km+'
       END                                               AS distance_bucket,
       CASE
           WHEN t.start_station_id = t.end_station_id THEN 0
           WHEN t.distance_m < 1000 THEN 1
           WHEN t.distance_m < 2000 THEN 2
           WHEN t.distance_m < 3000 THEN 3
           WHEN t.distance_m < 5000 THEN 4
           ELSE 5
       END                                               AS distance_bucket_order,
       HOUR(t.started_at)                                AS start_hour,
       (DAYOFWEEK(t.started_at) BETWEEN 2 AND 6)         AS is_weekday,
       t.bike_type_id,
       bt.bike_type_name,
       t.rider_type_id,
       rt.rider_type_name,
       ss.municipality                                   AS start_municipality,
       ss.neighborhood_id                                AS start_neighborhood_id,
       es.municipality                                   AS end_municipality,
       es.neighborhood_id                                AS end_neighborhood_id
FROM trip t
JOIN v_station_active ss ON ss.station_id = t.start_station_id
JOIN v_station_active es ON es.station_id = t.end_station_id
JOIN bike_type bt        ON bt.bike_type_id = t.bike_type_id
JOIN rider_type rt       ON rt.rider_type_id = t.rider_type_id;


-- ---------------------------------------------------------------------------
-- v_station_ridership
-- One row per active station.
--   sample_starts, sample_ends, sample_total  from the 100k sample (v_trip_clean).
--     Use these when you need to join to individual trips.
--   trips_jul_sep_2026, avg_daily_trips  from the FULL 1.66M trips.
--     Prefer these for ranking stations; sample counts are about 1/16.6 of real
--     and too small to rank quiet stations reliably.
--   ridership_quartile  Boston stations only, by trips_jul_sep_2026.
--     4 = busiest quarter, 1 = quietest. NULL outside Boston.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_station_ridership AS
SELECT s.station_id,
       s.station_name,
       s.municipality,
       s.neighborhood_id,
       s.station_cohort,
       s.is_new_station,
       COALESCE(st.n, 0)                        AS sample_starts,
       COALESCE(en.n, 0)                        AS sample_ends,
       COALESCE(st.n, 0) + COALESCE(en.n, 0)    AS sample_total,
       s.trips_jul_sep_2026,
       s.avg_daily_trips,
       CASE WHEN s.municipality = 'Boston' THEN
           NTILE(4) OVER (PARTITION BY s.municipality = 'Boston'
                          ORDER BY s.trips_jul_sep_2026)
       END                                      AS ridership_quartile
FROM v_station_active s
LEFT JOIN (SELECT start_station_id AS station_id, COUNT(*) AS n
           FROM v_trip_clean GROUP BY start_station_id) st
       ON st.station_id = s.station_id
LEFT JOIN (SELECT end_station_id AS station_id, COUNT(*) AS n
           FROM v_trip_clean GROUP BY end_station_id) en
       ON en.station_id = s.station_id;


-- ---------------------------------------------------------------------------
-- v_recent_crash
-- Bike crashes from 2023-01-01 onward. nearest_station_id was matched to
-- today's stations, so older crashes may be matched to stations that
-- didn't exist yet.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_recent_crash AS
SELECT c.*
FROM crash c
WHERE c.crash_ts >= '2023-01-01';


-- ---------------------------------------------------------------------------
-- check: row counts for every view
-- ---------------------------------------------------------------------------
SELECT 'v_station_active' AS view_name, COUNT(*) AS n FROM v_station_active
UNION ALL SELECT 'v_trip_clean',        COUNT(*) FROM v_trip_clean
UNION ALL SELECT 'v_station_ridership', COUNT(*) FROM v_station_ridership
UNION ALL SELECT 'v_recent_crash',      COUNT(*) FROM v_recent_crash;
