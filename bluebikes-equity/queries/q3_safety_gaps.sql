-- Query 3: Safety gaps
-- Question: Which high ridership Boston stations have no protected bike lane nearby
--           but have had bike crashes close to them since 2023?
-- Owner: Rachel Chertok
-- Notes: "High ridership" = top quartile of Boston stations by full-data trips
--        (ridership_quartile = 4 in v_station_ridership). "No protected lane nearby"
--        = nearest protected lane more than 100m away. Crashes come from
--        v_recent_crash (2023 onward, since crashes were matched to today's
--        stations) and count if this station is the crash's closest station and
--        it's within 150m. Lane data is the 2022 version, so a few newer lanes
--        may be missing. Boston only because lanes and crashes only cover Boston.
--        painted_lanes_within_100m shows whether there's at least a painted lane.
--        The same query with adjustable distances is the stored procedure
--        sp_safety_gaps in procedures.sql.

USE bluebikes;

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
                      AND c.nearest_station_m <= 150
WHERE r.municipality = 'Boston'
  AND r.ridership_quartile = 4
  AND s.nearest_protected_lane_m > 100
GROUP BY r.station_id, r.station_name, n.neighborhood_name,
         r.trips_jul_sep_2026, s.nearest_protected_lane_m
ORDER BY crashes_since_2023 DESC, r.trips_jul_sep_2026 DESC;
