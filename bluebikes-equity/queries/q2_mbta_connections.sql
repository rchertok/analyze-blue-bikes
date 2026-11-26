-- Query 2: MBTA connections
-- Question: What share of Bluebikes trips start or end near an MBTA rapid transit stop?
-- Owner: Rachel Chertok
-- Notes: "Near" = a subway, Green Line, or Silver Line stop (has_rapid_transit = 1)
--        within 400m of the station (station_mbta_access). We don't count bus stops
--        because almost every station has one within 400m. Uses v_trip_clean (no
--        depot, no inactive stations). Round trips are kept since this is about
--        ridership. First row is every trip, second row is only trips that start
--        and end in Boston. Percents are used because the sample is ~1/16.6 of
--        the real trip count.

USE bluebikes;

WITH trip_flags AS (
    SELECT t.ride_id,
           (t.start_municipality = 'Boston' AND t.end_municipality = 'Boston') AS is_boston_trip,
           EXISTS (SELECT 1
                   FROM station_mbta_access a
                   JOIN mbta_stop m ON m.stop_id = a.stop_id
                   WHERE a.station_id = t.start_station_id
                     AND m.has_rapid_transit = 1)                              AS start_near_t,
           EXISTS (SELECT 1
                   FROM station_mbta_access a
                   JOIN mbta_stop m ON m.stop_id = a.stop_id
                   WHERE a.station_id = t.end_station_id
                     AND m.has_rapid_transit = 1)                              AS end_near_t
    FROM v_trip_clean t
)
SELECT 'All trips'                                        AS trip_scope,
       COUNT(*)                                           AS trips,
       ROUND(100 * AVG(start_near_t), 1)                  AS pct_start_near_t,
       ROUND(100 * AVG(end_near_t), 1)                    AS pct_end_near_t,
       ROUND(100 * AVG(start_near_t OR end_near_t), 1)    AS pct_start_or_end_near_t,
       ROUND(100 * AVG(start_near_t AND end_near_t), 1)   AS pct_both_near_t,
       ROUND(100 * AVG(NOT start_near_t AND NOT end_near_t), 1) AS pct_neither
FROM trip_flags
UNION ALL
SELECT 'Boston only',
       COUNT(*),
       ROUND(100 * AVG(start_near_t), 1),
       ROUND(100 * AVG(end_near_t), 1),
       ROUND(100 * AVG(start_near_t OR end_near_t), 1),
       ROUND(100 * AVG(start_near_t AND end_near_t), 1),
       ROUND(100 * AVG(NOT start_near_t AND NOT end_near_t), 1)
FROM trip_flags
WHERE is_boston_trip = 1;
