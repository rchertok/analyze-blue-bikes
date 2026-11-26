-- Who Does Bluebikes Actually Serve?
-- Stored procedures (MySQL 8). Run after schema.sql, load.sql, and clean_views.sql.

USE bluebikes;

-- ---------------------------------------------------------------------------
-- sp_safety_gaps
-- Query 3 with the distances as parameters, so we can see how the list
-- changes if "nearby" means something different.
--   p_lane_m   a station counts as having no protected lane if the nearest
--              protected lane is more than this many meters away
--   p_crash_m  a crash counts if this station is its closest station and it's
--              within this many meters
-- Only top quartile Boston stations (ridership_quartile = 4) and crashes from
-- 2023 onward (v_recent_crash). station_lane only goes out to 100m, so
-- painted_lanes_within_100m stays at 100m no matter what p_lane_m is.
-- Example: CALL sp_safety_gaps(100, 150);
-- ---------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_safety_gaps;

DELIMITER //
CREATE PROCEDURE sp_safety_gaps(IN p_lane_m INT, IN p_crash_m INT)
BEGIN
    SELECT r.station_id,
           r.station_name,
           n.neighborhood_name,
           r.trips_jul_sep_2026,
           s.nearest_protected_lane_m,
           (SELECT COUNT(*)
            FROM station_lane sl
            JOIN bike_lane_segment b ON b.segment_id = sl.segment_id
            JOIN facility_type f     ON f.facility_code = b.facility_code
            WHERE sl.station_id = r.station_id
              AND f.protection_level = 'painted')      AS painted_lanes_within_100m,
           COUNT(c.crash_id)                           AS crashes_since_2023,
           DATE(MAX(c.crash_ts))                       AS most_recent_crash
    FROM v_station_ridership r
    JOIN station s         ON s.station_id = r.station_id
    JOIN neighborhood n    ON n.neighborhood_id = r.neighborhood_id
    JOIN v_recent_crash c  ON c.nearest_station_id = r.station_id
                          AND c.nearest_station_m <= p_crash_m
    WHERE r.municipality = 'Boston'
      AND r.ridership_quartile = 4
      AND s.nearest_protected_lane_m > p_lane_m
    GROUP BY r.station_id, r.station_name, n.neighborhood_name,
             r.trips_jul_sep_2026, s.nearest_protected_lane_m
    ORDER BY crashes_since_2023 DESC, r.trips_jul_sep_2026 DESC;
END //
DELIMITER ;

-- check: should match queries/q3_safety_gaps.sql
CALL sp_safety_gaps(100, 150);
