# Who Does Bluebikes Actually Serve?

CS3200 group project: Rachel Chertok, Linh Le, Amy Tran, Marissa Shapiro

We connect Bluebikes stations and trips to Boston neighborhoods, MBTA stops, the city's bike lane network, and bike crash records to see whether the system's growth is reaching the neighborhoods that need it most.

## Setup

1. Clone the repo (or download it from the Drive folder).
2. Open a terminal in this folder and run:

```
mysql --local-infile=1 -u root -p < schema.sql
mysql --local-infile=1 -u root -p < load.sql
```

The last thing load.sql prints is a row count for every table. If any of them say 0, something went wrong, so check the error above it.

**If you use MySQL Workbench instead of the terminal:** edit your connection, go to Advanced, and put `OPT_LOCAL_INFILE=1` in the Others box. Then in load.sql, replace every `'data/` with the full path to this folder's data folder, like `'/Users/you/bluebikes-equity/data/`. Windows paths need forward slashes.

## Trips: sample vs full

`data/trip_sample_100k.csv` is a random 100k of the July to September 2026 trips and is what load.sql uses. It's plenty for our queries. The full 1.66M trips are in `trip_full.zip` in the Drive. Only switch if we need it, and if you do, unzip it into `data/` and change the file name in load.sql.

## Tables

| Table | What it is | Rows |
|---|---|---|
| neighborhood | Boston's 24 neighborhoods | 24 |
| neighborhood_demographics | ACS 2020-2024 population, income, car ownership, poverty, commute mode | 24 |
| station | Bluebikes stations, with neighborhood, distance to nearest protected lane, station age cohort, and avg daily trips | 636 |
| trip | Bluebikes trips (sample) | 100,000 |
| bike_type | classic or electric | 2 |
| rider_type | member or casual | 2 |
| bike_lane_segment | city bike network segments (2022 version) | 3,159 |
| facility_type | what each lane code means and whether it counts as protected | 16 |
| station_lane | lane segments within 100m of a station | 1,483 |
| mbta_stop | T, commuter rail, ferry, and bus stops within 1km of a station | 3,772 |
| station_mbta_access | MBTA stops within 400m of a station | 6,512 |
| crash | Vision Zero bike crashes, 2015 to Oct 2026 | 4,128 |

## Things to keep in mind when writing queries

- Neighborhoods, bike lanes, and crashes only cover Boston, so filter to `municipality = 'Boston'` for anything about equity, lanes, or safety.
- Station `X32999` is a Bluebikes depot, not a real station. Leave it out of ridership numbers.
- About 3.5% of trips start and end at the same station, so `distance_m = 0`. Filter those out for trip length questions.
- For "near the T," use `has_rapid_transit = 1`. Bus stops are everywhere so they make every station look connected.
- Crash `nearest_station_id` uses today's stations, so stick to recent years (2023+) when matching crashes to stations.
- The bike lane file is the 2022 version, so newer lanes are missing.

## Queries

Put each query in `queries/` as its own file (`q1_station_access.sql`, etc.). Copy `q_template.sql` to start. Every query needs the English question as a comment above it, and we paste the output under it in the final PDF.

## Data sources

- Bluebikes System Data (trips): bluebikes.com/system-data
- Analyze Boston: Blue Bike Stations, Existing Bike Network (2022), Vision Zero Crash Records, Neighborhood Boundaries Approximated by 2020 Census Tracts
- MBTA GTFS feed
- U.S. Census American Community Survey 2020-2024 5-year estimates (via the Census API)
- Analyze Boston: 2020 Census Tracts in Boston

## How we used AI

Claude did the data cleaning, rolled census tracts up to neighborhoods, and built the tables from the raw files we downloaded. That included the spatial joins (matching stations to neighborhoods, lanes, MBTA stops, and crashes) and writing the schema and load scripts. We picked the topic, data sources, and research questions, decided what to keep and what to filter, and checked the results.
