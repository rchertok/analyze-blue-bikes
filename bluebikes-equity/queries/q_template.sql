-- Query X: [short title]
-- Question: [the question in plain English, the way it'll show up in the PDF]
-- Owner: [your name]
-- Notes: [anything someone should know, like filters or assumptions]

USE bluebikes;

-- example so you can see the format (delete when you write yours):
-- How many trips started at each Boston neighborhood's stations, and what share were on e-bikes?
SELECT n.neighborhood_name,
       COUNT(*) AS trips,
       ROUND(100 * AVG(t.bike_type_id = 2), 1) AS pct_ebike
FROM trip t
JOIN station s      ON t.start_station_id = s.station_id
JOIN neighborhood n ON s.neighborhood_id  = n.neighborhood_id
GROUP BY n.neighborhood_name
ORDER BY trips DESC;
