-- Query 1: Residents per station vs. income
-- Question: Which neighborhoods have the most residents per Bluebikes station,
--           and how does that compare to household income?
-- Owner: Rachel Chertok
-- Notes: The census data has mean household income, not median (medians can't be
--        added up across tracts), so we use mean. LEFT JOIN so neighborhoods with
--        no stations would still show up. Harbor Islands is excluded (no stations,
--        29 residents, 0 households). Population includes dorms, so we also show
--        households per station since Longwood, Fenway, Allston, and Mission Hill
--        have a lot of students. income_rank 1 = lowest income.

USE bluebikes;

SELECT n.neighborhood_name,
       d.population,
       COUNT(s.station_id)                                       AS stations,
       ROUND(d.population / NULLIF(COUNT(s.station_id), 0))      AS residents_per_station,
       ROUND(d.households / NULLIF(COUNT(s.station_id), 0))      AS households_per_station,
       d.mean_household_income,
       RANK() OVER (ORDER BY d.mean_household_income)            AS income_rank,
       d.pct_below_poverty
FROM neighborhood n
JOIN neighborhood_demographics d ON d.neighborhood_id = n.neighborhood_id
LEFT JOIN v_station_active s     ON s.neighborhood_id = n.neighborhood_id
WHERE n.neighborhood_name <> 'Harbor Islands'
GROUP BY n.neighborhood_id, n.neighborhood_name, d.population, d.households,
         d.mean_household_income, d.pct_below_poverty
ORDER BY residents_per_station DESC;
