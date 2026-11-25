-- Loads every CSV in data/ into the bluebikes database.
-- Run schema.sql first. Order matters because of foreign keys.
-- Paths are relative to the repo folder, so start mysql from there:
--   mysql --local-infile=1 -u root -p < schema.sql
--   mysql --local-infile=1 -u root -p < load.sql
-- (Workbench users: see the README.)

USE bluebikes;
SET GLOBAL local_infile = 1;

-- lookup tables
LOAD DATA LOCAL INFILE 'data/bike_type.csv' INTO TABLE bike_type
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'data/rider_type.csv' INTO TABLE rider_type
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'data/facility_type.csv' INTO TABLE facility_type
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'data/neighborhood.csv' INTO TABLE neighborhood
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'data/neighborhood_demographics.csv' INTO TABLE neighborhood_demographics
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(neighborhood_id, acs_year, n_tracts, population, households, aggregate_income, @inc,
 no_vehicle_households, @pnv, poverty_universe, below_poverty, @ppov, workers, transit_commuters,
 bike_commuters, @ptr, @pbike, pop_density_per_sq_km)
SET mean_household_income = NULLIF(@inc, ''),
    pct_no_vehicle        = NULLIF(@pnv, ''),
    pct_below_poverty     = NULLIF(@ppov, ''),
    pct_commute_transit   = NULLIF(@ptr, ''),
    pct_commute_bike      = NULLIF(@pbike, '');

-- stations (empty cells become NULL)
LOAD DATA LOCAL INFILE 'data/station.csv' INTO TABLE station
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(station_id, station_name, lat, lon, municipality, @nbhd, @docks, in_city_station_file, @first_trip, @prot,
 station_cohort, is_new_station, trips_jul_sep_2026, @avg_daily)
SET neighborhood_id          = NULLIF(@nbhd, ''),
    total_docks              = NULLIF(@docks, ''),
    first_trip_in_data       = NULLIF(@first_trip, ''),
    nearest_protected_lane_m = NULLIF(@prot, ''),
    avg_daily_trips          = NULLIF(@avg_daily, '');

-- trips: uses the 100k sample by default
-- for the full 1.66M trips, unzip trip_full.zip into data/ and change the file name to data/trip.csv
LOAD DATA LOCAL INFILE 'data/trip_sample_100k.csv' INTO TABLE trip
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(ride_id, start_station_id, end_station_id, started_at, ended_at, duration_sec, @dist, bike_type_id, rider_type_id)
SET distance_m = NULLIF(@dist, '');

-- bike lanes
LOAD DATA LOCAL INFILE 'data/bike_lane_segment.csv' INTO TABLE bike_lane_segment
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(segment_id, street_name, facility_code, @yr, length_m, @nbhd)
SET install_year    = NULLIF(@yr, ''),
    neighborhood_id = NULLIF(@nbhd, '');

LOAD DATA LOCAL INFILE 'data/station_lane.csv' INTO TABLE station_lane
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

-- MBTA
-- a few stops have more than 6 decimals in lat/lon, so round them explicitly
LOAD DATA LOCAL INFILE 'data/mbta_stop.csv' INTO TABLE mbta_stop
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(stop_id, stop_name, @lat, @lon, municipality, primary_mode, has_rapid_transit, has_commuter_rail,
 has_bus, has_ferry, n_routes, wheelchair_boarding)
SET lat = ROUND(@lat, 6),
    lon = ROUND(@lon, 6);

LOAD DATA LOCAL INFILE 'data/station_mbta_access.csv' INTO TABLE station_mbta_access
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

-- crashes
LOAD DATA LOCAL INFILE 'data/crash.csv' INTO TABLE crash
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(crash_id, crash_ts, location_type, @street, @x1, @x2, lat, lon, nearest_station_id, nearest_station_m)
SET street   = NULLIF(@street, ''),
    xstreet1 = NULLIF(@x1, ''),
    xstreet2 = NULLIF(@x2, '');

-- quick check: every table should have rows
SELECT 'bike_type' AS tbl, COUNT(*) AS n FROM bike_type
UNION ALL SELECT 'rider_type', COUNT(*) FROM rider_type
UNION ALL SELECT 'facility_type', COUNT(*) FROM facility_type
UNION ALL SELECT 'neighborhood', COUNT(*) FROM neighborhood
UNION ALL SELECT 'neighborhood_demographics', COUNT(*) FROM neighborhood_demographics
UNION ALL SELECT 'station', COUNT(*) FROM station
UNION ALL SELECT 'trip', COUNT(*) FROM trip
UNION ALL SELECT 'bike_lane_segment', COUNT(*) FROM bike_lane_segment
UNION ALL SELECT 'station_lane', COUNT(*) FROM station_lane
UNION ALL SELECT 'mbta_stop', COUNT(*) FROM mbta_stop
UNION ALL SELECT 'station_mbta_access', COUNT(*) FROM station_mbta_access
UNION ALL SELECT 'crash', COUNT(*) FROM crash;
