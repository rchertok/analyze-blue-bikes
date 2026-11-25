-- Who Does Bluebikes Actually Serve?
-- Checks that the clean views follow every cleaning rule in CLAUDE.md.
-- Run after clean_views.sql. Each row counts the rows that BREAK a rule.
-- Every check should be 0 except check 32 (see note there), and the
-- result column says pass or FAIL.

USE bluebikes;

SELECT chk, view_name, rule, violations, expected,
       IF(violations = expected, 'pass', 'FAIL') AS result
FROM (

-- ---------- v_station_active ----------
SELECT 1 AS chk, 'v_station_active' AS view_name,
       'depot X32999 or Hingham BCBS01 present' AS rule,
       (SELECT COUNT(*) FROM v_station_active WHERE station_id IN ('X32999', 'BCBS01')) AS violations
UNION ALL SELECT 2, 'v_station_active', 'inactive station present',
       (SELECT COUNT(*) FROM v_station_active WHERE station_cohort = 'inactive')
UNION ALL SELECT 3, 'v_station_active', 'station with no 2026 trips or missing avg_daily_trips',
       (SELECT COUNT(*) FROM v_station_active WHERE trips_jul_sep_2026 <= 0 OR avg_daily_trips IS NULL)
UNION ALL SELECT 4, 'v_station_active', 'Boston station missing neighborhood_id',
       (SELECT COUNT(*) FROM v_station_active WHERE municipality = 'Boston' AND neighborhood_id IS NULL)
UNION ALL SELECT 5, 'v_station_active', 'non-Boston station has a neighborhood_id',
       (SELECT COUNT(*) FROM v_station_active WHERE municipality <> 'Boston' AND neighborhood_id IS NOT NULL)
UNION ALL SELECT 6, 'v_station_active', 'station in Harbor Islands',
       (SELECT COUNT(*) FROM v_station_active s JOIN neighborhood n ON n.neighborhood_id = s.neighborhood_id
        WHERE n.neighborhood_name = 'Harbor Islands')
UNION ALL SELECT 7, 'v_station_active', 'is_new_station disagrees with station_cohort',
       (SELECT COUNT(*) FROM v_station_active WHERE is_new_station <> (station_cohort = 'after_sep_2025'))
UNION ALL SELECT 8, 'v_station_active', 'duplicate station_id',
       (SELECT COUNT(*) - COUNT(DISTINCT station_id) FROM v_station_active)

-- ---------- v_trip_clean ----------
UNION ALL SELECT 9, 'v_trip_clean', 'missing start or end station id',
       (SELECT COUNT(*) FROM v_trip_clean WHERE start_station_id IS NULL OR end_station_id IS NULL)
UNION ALL SELECT 10, 'v_trip_clean', 'start or end station not in v_station_active',
       (SELECT COUNT(*) FROM v_trip_clean t
        WHERE NOT EXISTS (SELECT 1 FROM v_station_active s WHERE s.station_id = t.start_station_id)
           OR NOT EXISTS (SELECT 1 FROM v_station_active s WHERE s.station_id = t.end_station_id))
UNION ALL SELECT 11, 'v_trip_clean', 'trip touches depot or Hingham station',
       (SELECT COUNT(*) FROM v_trip_clean
        WHERE start_station_id IN ('X32999', 'BCBS01') OR end_station_id IN ('X32999', 'BCBS01'))
UNION ALL SELECT 12, 'v_trip_clean', 'duration under 60 sec or over 4 hours',
       (SELECT COUNT(*) FROM v_trip_clean WHERE duration_sec < 60 OR duration_sec > 4 * 3600)
UNION ALL SELECT 13, 'v_trip_clean', 'ended_at before or equal to started_at',
       (SELECT COUNT(*) FROM v_trip_clean WHERE ended_at <= started_at)
UNION ALL SELECT 14, 'v_trip_clean', 'duration_sec off from ended_at - started_at by > 1 sec',
       (SELECT COUNT(*) FROM v_trip_clean
        WHERE ABS(TIMESTAMPDIFF(SECOND, started_at, ended_at) - duration_sec) > 1)
UNION ALL SELECT 15, 'v_trip_clean', 'trip ends outside Jul 1 to Sep 30 2026',
       (SELECT COUNT(*) FROM v_trip_clean
        WHERE ended_at < '2026-07-01' OR ended_at >= '2026-10-01')
UNION ALL SELECT 16, 'v_trip_clean', 'missing or negative distance_m',
       (SELECT COUNT(*) FROM v_trip_clean WHERE distance_m IS NULL OR distance_m < 0)
UNION ALL SELECT 17, 'v_trip_clean', 'is_round_trip disagrees with start = end station',
       (SELECT COUNT(*) FROM v_trip_clean WHERE is_round_trip <> (start_station_id = end_station_id))
UNION ALL SELECT 18, 'v_trip_clean', 'non-round trip with distance_m = 0',
       (SELECT COUNT(*) FROM v_trip_clean WHERE is_round_trip = 0 AND distance_m = 0)
UNION ALL SELECT 19, 'v_trip_clean', 'distance_bucket does not match distance_m',
       (SELECT COUNT(*) FROM v_trip_clean
        WHERE NOT (   (is_round_trip = 1 AND distance_bucket = 'round trip'  AND distance_bucket_order = 0)
                   OR (is_round_trip = 0 AND distance_m <  1000 AND distance_bucket = 'under 1km' AND distance_bucket_order = 1)
                   OR (is_round_trip = 0 AND distance_m >= 1000 AND distance_m < 2000 AND distance_bucket = '1 to 2km' AND distance_bucket_order = 2)
                   OR (is_round_trip = 0 AND distance_m >= 2000 AND distance_m < 3000 AND distance_bucket = '2 to 3km' AND distance_bucket_order = 3)
                   OR (is_round_trip = 0 AND distance_m >= 3000 AND distance_m < 5000 AND distance_bucket = '3 to 5km' AND distance_bucket_order = 4)
                   OR (is_round_trip = 0 AND distance_m >= 5000 AND distance_bucket = '5km+' AND distance_bucket_order = 5)))
UNION ALL SELECT 20, 'v_trip_clean', 'duration_min does not match duration_sec / 60',
       (SELECT COUNT(*) FROM v_trip_clean WHERE ABS(duration_min - duration_sec / 60) > 0.05)
UNION ALL SELECT 21, 'v_trip_clean', 'start_hour or is_weekday does not match started_at',
       (SELECT COUNT(*) FROM v_trip_clean
        WHERE start_hour <> HOUR(started_at)
           OR is_weekday <> (DAYOFWEEK(started_at) BETWEEN 2 AND 6))
UNION ALL SELECT 22, 'v_trip_clean', 'missing bike or rider type',
       (SELECT COUNT(*) FROM v_trip_clean WHERE bike_type_name IS NULL OR rider_type_name IS NULL)
UNION ALL SELECT 23, 'v_trip_clean', 'Boston start/end station missing neighborhood_id',
       (SELECT COUNT(*) FROM v_trip_clean
        WHERE (start_municipality = 'Boston' AND start_neighborhood_id IS NULL)
           OR (end_municipality = 'Boston' AND end_neighborhood_id IS NULL))
UNION ALL SELECT 24, 'v_trip_clean', 'duplicate ride_id',
       (SELECT COUNT(*) - COUNT(DISTINCT ride_id) FROM v_trip_clean)

-- ---------- v_station_ridership ----------
UNION ALL SELECT 25, 'v_station_ridership', 'station count differs from v_station_active',
       (SELECT ABS((SELECT COUNT(*) FROM v_station_ridership) - (SELECT COUNT(*) FROM v_station_active)))
UNION ALL SELECT 26, 'v_station_ridership', 'sample starts or ends do not add up to v_trip_clean',
       (SELECT ABS((SELECT SUM(sample_starts) FROM v_station_ridership) - (SELECT COUNT(*) FROM v_trip_clean))
             + ABS((SELECT SUM(sample_ends)   FROM v_station_ridership) - (SELECT COUNT(*) FROM v_trip_clean)))
UNION ALL SELECT 27, 'v_station_ridership', 'quartile missing for Boston or set outside Boston',
       (SELECT COUNT(*) FROM v_station_ridership
        WHERE (municipality = 'Boston' AND ridership_quartile NOT BETWEEN 1 AND 4)
           OR (municipality = 'Boston' AND ridership_quartile IS NULL)
           OR (municipality <> 'Boston' AND ridership_quartile IS NOT NULL))
UNION ALL SELECT 28, 'v_station_ridership', 'quartiles overlap (a lower quartile has more trips)',
       (SELECT COUNT(*) FROM v_station_ridership a JOIN v_station_ridership b
          ON b.ridership_quartile = a.ridership_quartile + 1
        WHERE a.trips_jul_sep_2026 > b.trips_jul_sep_2026)

-- ---------- v_recent_crash ----------
UNION ALL SELECT 29, 'v_recent_crash', 'crash before 2023-01-01',
       (SELECT COUNT(*) FROM v_recent_crash WHERE crash_ts < '2023-01-01')
UNION ALL SELECT 30, 'v_recent_crash', 'crash dated in the future',
       (SELECT COUNT(*) FROM v_recent_crash WHERE crash_ts > NOW())
UNION ALL SELECT 31, 'v_recent_crash', 'missing nearest_station_id or distance',
       (SELECT COUNT(*) FROM v_recent_crash WHERE nearest_station_id IS NULL OR nearest_station_m IS NULL OR nearest_station_m < 0)
-- Known: 5 crashes (2928, 3076, 3614, 3825, 3987) have an excluded station as
-- their nearest station, because nearest_station_id was computed against all
-- stations. Their nearest ACTIVE station is 207 to 877m away, so none of them
-- would count in q3 (which uses crashes within 150m) either way.
UNION ALL SELECT 32, 'v_recent_crash', 'nearest station is depot, Hingham, or inactive (known: 5)',
       (SELECT COUNT(*) FROM v_recent_crash c
        WHERE NOT EXISTS (SELECT 1 FROM v_station_active s WHERE s.station_id = c.nearest_station_id))
) checks
CROSS JOIN LATERAL (SELECT CASE checks.chk WHEN 32 THEN 5 ELSE 0 END AS expected) e
ORDER BY chk;
