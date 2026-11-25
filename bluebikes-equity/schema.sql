-- Who Does Bluebikes Actually Serve?
-- CS3200 group project schema (MySQL 8)
-- Run this first, then load.sql

DROP DATABASE IF EXISTS bluebikes;
CREATE DATABASE bluebikes CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE bluebikes;

-- ---------- lookup tables ----------

CREATE TABLE bike_type (
    bike_type_id    INT PRIMARY KEY,
    bike_type_name  VARCHAR(20) NOT NULL UNIQUE      -- classic_bike, electric_bike
);

CREATE TABLE rider_type (
    rider_type_id   INT PRIMARY KEY,
    rider_type_name VARCHAR(20) NOT NULL UNIQUE      -- member, casual
);

CREATE TABLE facility_type (
    facility_code        VARCHAR(12) PRIMARY KEY,    -- code used in the city's bike network file
    facility_description VARCHAR(80) NOT NULL,
    protection_level     ENUM('protected','painted','shared','other') NOT NULL,
    is_protected         TINYINT(1) NOT NULL
);

-- ---------- neighborhoods ----------

CREATE TABLE neighborhood (
    neighborhood_id   INT PRIMARY KEY,
    neighborhood_name VARCHAR(40) NOT NULL UNIQUE,
    area_sq_km        DECIMAL(6,2) NOT NULL
);

-- census ACS data rolled up from tracts to neighborhoods
CREATE TABLE neighborhood_demographics (
    neighborhood_id         INT PRIMARY KEY,
    acs_year                SMALLINT NOT NULL,       -- ACS 5-year 2020-2024
    n_tracts                SMALLINT NOT NULL,
    population              INT NOT NULL,            -- includes people in dorms and other group quarters
    households              INT NOT NULL,
    aggregate_income        BIGINT NOT NULL,
    mean_household_income   INT NULL,                -- aggregate_income / households (NULL if no households)
    no_vehicle_households   INT NOT NULL,
    pct_no_vehicle          DECIMAL(5,2) NULL,
    poverty_universe        INT NOT NULL,
    below_poverty           INT NOT NULL,
    pct_below_poverty       DECIMAL(5,2) NULL,
    workers                 INT NOT NULL,
    transit_commuters       INT NOT NULL,
    bike_commuters          INT NOT NULL,
    pct_commute_transit     DECIMAL(5,2) NULL,
    pct_commute_bike        DECIMAL(5,2) NULL,
    pop_density_per_sq_km   INT NOT NULL,
    FOREIGN KEY (neighborhood_id) REFERENCES neighborhood(neighborhood_id)
);

-- ---------- bluebikes ----------

CREATE TABLE station (
    station_id               VARCHAR(10) PRIMARY KEY,
    station_name             VARCHAR(100) NOT NULL,
    lat                      DECIMAL(9,6) NOT NULL,
    lon                      DECIMAL(9,6) NOT NULL,
    municipality             VARCHAR(30) NOT NULL,
    neighborhood_id          INT NULL,               -- NULL for stations outside Boston
    total_docks              SMALLINT NULL,          -- NULL for stations missing from the city station file
    in_city_station_file     TINYINT(1) NOT NULL,
    first_trip_in_data       DATE NULL,
    nearest_protected_lane_m INT NULL,
    station_cohort           ENUM('before_jul_2025','aug_sep_2025','after_sep_2025','inactive') NOT NULL,  -- when the station first shows up in trip data
    is_new_station           TINYINT(1) NOT NULL,    -- 1 = after_sep_2025 (no trips at all in Jul to Sep 2025)
    trips_jul_sep_2026       INT NOT NULL,           -- starts + ends from the FULL trip data, not the sample
    avg_daily_trips          DECIMAL(7,2) NULL,      -- trips_jul_sep_2026 / days since first trip in window (NULL for inactive stations)
    FOREIGN KEY (neighborhood_id) REFERENCES neighborhood(neighborhood_id)
);

CREATE TABLE trip (
    ride_id          CHAR(16) PRIMARY KEY,
    start_station_id VARCHAR(10) NOT NULL,
    end_station_id   VARCHAR(10) NOT NULL,
    started_at       DATETIME NOT NULL,
    ended_at         DATETIME NOT NULL,
    duration_sec     INT NOT NULL,
    distance_m       INT NULL,                       -- straight line between stations
    bike_type_id     INT NOT NULL,
    rider_type_id    INT NOT NULL,
    FOREIGN KEY (start_station_id) REFERENCES station(station_id),
    FOREIGN KEY (end_station_id)   REFERENCES station(station_id),
    FOREIGN KEY (bike_type_id)     REFERENCES bike_type(bike_type_id),
    FOREIGN KEY (rider_type_id)    REFERENCES rider_type(rider_type_id),
    INDEX idx_trip_started (started_at)
);

-- ---------- bike lanes ----------

CREATE TABLE bike_lane_segment (
    segment_id      INT PRIMARY KEY,
    street_name     VARCHAR(80),
    facility_code   VARCHAR(12) NOT NULL,
    install_year    SMALLINT NULL,
    length_m        INT NOT NULL,
    neighborhood_id INT NULL,
    FOREIGN KEY (facility_code)   REFERENCES facility_type(facility_code),
    FOREIGN KEY (neighborhood_id) REFERENCES neighborhood(neighborhood_id)
);

-- join table: lane segments within 100m of a station
CREATE TABLE station_lane (
    station_id VARCHAR(10) NOT NULL,
    segment_id INT NOT NULL,
    distance_m INT NOT NULL,
    PRIMARY KEY (station_id, segment_id),
    FOREIGN KEY (station_id) REFERENCES station(station_id),
    FOREIGN KEY (segment_id) REFERENCES bike_lane_segment(segment_id)
);

-- ---------- MBTA ----------

CREATE TABLE mbta_stop (
    stop_id             VARCHAR(30) PRIMARY KEY,
    stop_name           VARCHAR(100) NOT NULL,
    lat                 DECIMAL(9,6) NOT NULL,
    lon                 DECIMAL(9,6) NOT NULL,
    municipality        VARCHAR(30),
    primary_mode        ENUM('rapid_transit','commuter_rail','ferry','bus') NOT NULL,
    has_rapid_transit   TINYINT(1) NOT NULL,
    has_commuter_rail   TINYINT(1) NOT NULL,
    has_bus             TINYINT(1) NOT NULL,
    has_ferry           TINYINT(1) NOT NULL,
    n_routes            SMALLINT NOT NULL,
    wheelchair_boarding TINYINT NOT NULL
);

-- join table: MBTA stops within 400m of a station
CREATE TABLE station_mbta_access (
    station_id VARCHAR(10) NOT NULL,
    stop_id    VARCHAR(30) NOT NULL,
    distance_m INT NOT NULL,
    PRIMARY KEY (station_id, stop_id),
    FOREIGN KEY (station_id) REFERENCES station(station_id),
    FOREIGN KEY (stop_id)    REFERENCES mbta_stop(stop_id)
);

-- ---------- crashes ----------

CREATE TABLE crash (
    crash_id           INT PRIMARY KEY,
    crash_ts           DATETIME NOT NULL,            -- Boston local time
    location_type      VARCHAR(20) NOT NULL,
    street             VARCHAR(60),
    xstreet1           VARCHAR(60),
    xstreet2           VARCHAR(60),
    lat                DECIMAL(9,6) NOT NULL,
    lon                DECIMAL(9,6) NOT NULL,
    nearest_station_id VARCHAR(10) NOT NULL,
    nearest_station_m  INT NOT NULL,
    FOREIGN KEY (nearest_station_id) REFERENCES station(station_id),
    INDEX idx_crash_ts (crash_ts)
);
