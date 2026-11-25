# CLAUDE.md

CS3200 (Intro to Databases) group project at Northeastern: "Who Does Bluebikes Actually Serve?"
Team: Rachel Chertok, Linh Le, Amy Tran, Marissa Shapiro. MySQL 8.

@README.md

## Assignment requirements
- 7 to 10+ tables including join tables (we have 12)
- 5 or 6 non-trivial SQL queries using joins and/or subqueries, each with the English question as a comment above it and the output shown
- 5 or 6 slide presentation including an EER diagram
- Stored procedures, functions, and triggers are optional but count in our favor
- We have to explain how AI was used, so keep the "How we used AI" section in README.md accurate

## How the data was built
The CSVs in data/ were built in a separate Claude chat from raw files we downloaded. Don't rebuild them from scratch.
- Trips: Bluebikes July, August, September 2026. 1.66M trips after cleaning. Repo uses a random 100k sample (trip_sample_100k.csv, random_state=42). Removed trips with no start or end station (4,373) and durations under 60 sec or over 4 hours (2,102). distance_m is straight-line haversine between stations.
- Stations: station_cohort, is_new_station, trips_jul_sep_2026, avg_daily_trips were added from Jul to Sep 2025 trips plus the full 2026 trips.
- Stations (base): Analyze Boston station file (572) plus 64 stations that appear in trips but were missing from the city file (built from trip coordinates, in_city_station_file = 0, total_docks NULL). Municipality for those was assigned by neighborhood polygon or nearest known station.
- Neighborhoods: Analyze Boston boundaries approximated by 2020 census tracts. Stations assigned by point-in-polygon.
- Bike lanes: Analyze Boston Existing Bike Network 2022. facility_type maps the ExisFacil codes to protected / painted / shared / other. SUPM meaning is uncertain, treated as a shared use path (protected). station_lane = segments within 100m. station.nearest_protected_lane_m precomputed.
- MBTA: GTFS. Platforms collapsed into parent stations. Only stops within 1km of a Bluebikes station kept. Mode flags come from routes actually served. station_mbta_access = stops within 400m.
- Census: ACS 2020-2024 5-year, tract level for Suffolk County, pulled from the Census API. Each of Boston's 207 2020 tracts was assigned to a neighborhood by its internal point (one zero-population tract near Logan fell outside every polygon and was dropped). Counts are summed per neighborhood and percents recomputed from the sums. mean_household_income = aggregate income / households (median can't be summed across tracts). Tracts with no households had a Census null code for income, set to 0.
- Crashes: Vision Zero, mode_type = 'bike' only, timestamps converted from UTC to Boston local time. nearest_station_id is the closest current station.

## Known data issues
- Neighborhoods, lanes, and crashes only cover the City of Boston. Equity, lane, and safety queries must filter to municipality = 'Boston'.
- X32999 is a Bluebikes depot (153 trips). BCBS01 is a corporate station in Hingham (2 trips). Exclude both from ridership.
- Harbor Islands neighborhood has no stations, 29 residents, and 0 households. Exclude it from every demographic comparison.
- Population includes dorms and other group quarters. Longwood (5,317 people, 283 households) and student-heavy Fenway, Allston, and Mission Hill look more crowded per station and poorer than their permanent residents. Consider households as a second denominator.
- About 3.5% of trips are round trips (distance_m = 0). Exclude for trip length questions, keep for ridership counts.
- Trip counts in the sample are about 1/16.6 of real counts. Prefer percentages, averages, and rankings in query output.
- Bike lane data is from 2022, so lanes built 2023 to 2026 are missing.
- Crash to station matching uses current stations, so only use crashes from 2023 onward.
- Use has_rapid_transit = 1 for "near the T". Bus stops are within 400m of almost every station.
- There is no station install date. New stations are defined by comparison with July 2025 trips (see station_cohort).

## Cleaning approach
Don't delete or edit rows in the base tables. Put all cleaning in views in clean_views.sql (run after load.sql) so the raw data stays intact and every filter is visible for the writeup.

Views (built, see clean_views.sql comments for every column):
- v_station_active: stations excluding X32999, BCBS01, and the 14 inactive stations (no 2026 trips). 620 stations, 355 in Boston.
- v_trip_clean: trips where both stations are in v_station_active (99,990), plus is_round_trip (same start and end station, which catches 29 same-station trips with distance_m > 0), distance_bucket ('round trip', under 1km, 1 to 2km, 2 to 3km, 3 to 5km, 5km+) with distance_bucket_order, duration_min, start_hour, is_weekday, bike/rider type names, and start/end municipality and neighborhood_id
- v_station_ridership: per station sample starts, ends, total from v_trip_clean, plus full-data trips_jul_sep_2026 and avg_daily_trips. ridership_quartile is among Boston stations by trips_jul_sep_2026 (full data, not the sample), 4 = busiest, NULL outside Boston.
- v_recent_crash: crashes from 2023-01-01 onward (1,245)

## Per-question plan
1. Residents per station vs income: neighborhood LEFT JOIN v_station_active (so 0-station neighborhoods still show) joined to neighborhood_demographics. Exclude Harbor Islands.
2. Share of trips starting or ending near the T: v_trip_clean with EXISTS subqueries on station_mbta_access joined to mbta_stop where has_rapid_transit = 1. Report all trips and Boston-only.
3. High ridership stations with no protected lane nearby but recent crashes: Boston stations in the top ridership quartile from v_station_ridership, nearest_protected_lane_m > 100, joined to v_recent_crash where nearest_station_m <= 150. Good candidate for a stored procedure that takes the distance thresholds as parameters.
4. E-bike usage by neighborhood and trip length: v_trip_clean, Boston start stations only, exclude round trips, group by neighborhood and distance bucket, report percent e-bike.
5. New vs older stations: station_cohort is based on Jul to Sep 2025 trips (a station needs 5+ trips to count as present). before_jul_2025 = 557, aug_sep_2025 = 24 (opened during summer 2025, about a year old), after_sep_2025 = 41 (weren't there at all a year ago, is_new_station = 1), inactive = 14 (no 2026 trips, exclude). Compare avg_daily_trips across cohorts, ideally within the same neighborhood. avg_daily_trips comes from the FULL trip data and accounts for stations that opened partway through the window, so use it instead of counting the sample. No 2025 station IDs disappeared, so moved stations weren't an issue. Neighborhood-level comparisons have small counts (1 to 4 new stations each), so frame them as patterns.

## Conventions
- Table and column names are lowercase snake_case and match the CSV headers
- One query per file in queries/, named q1_short_name.sql, following queries/q_template.sql
- Every query starts with comments: title, the question in plain English, owner, notes
- Test every query on a fresh load (schema.sql then load.sql then clean_views.sql) before it goes in the PDF
