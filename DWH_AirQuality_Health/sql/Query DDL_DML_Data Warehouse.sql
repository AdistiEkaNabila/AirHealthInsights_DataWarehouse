-- PENGHAPUSAN TABEL
DROP TABLE IF EXISTS fact_air_quality_health CASCADE;
DROP TABLE IF EXISTS dim_time CASCADE;
DROP TABLE IF EXISTS dim_location CASCADE;
DROP TABLE IF EXISTS dim_indicator CASCADE;

-- PRIMARY KEY

ALTER TABLE dim_time
ADD PRIMARY KEY (time_id);

ALTER TABLE dim_location
ADD PRIMARY KEY (location_id);

ALTER TABLE dim_indicator
ADD PRIMARY KEY (indicator_key);

ALTER TABLE fact_air_quality_health
ADD PRIMARY KEY (fact_id);

-- FOREIGN KEY

ALTER TABLE fact_air_quality_health
ADD CONSTRAINT fk_time
FOREIGN KEY (time_id)
REFERENCES dim_time(time_id);

ALTER TABLE fact_air_quality_health
ADD CONSTRAINT fk_location
FOREIGN KEY (location_id)
REFERENCES dim_location(location_id);

ALTER TABLE fact_air_quality_health
ADD CONSTRAINT fk_indicator
FOREIGN KEY (indicator_key)
REFERENCES dim_indicator(indicator_key);

-- INDEX
CREATE INDEX IF NOT EXISTS idx_fact_time
ON fact_air_quality_health(time_id);

CREATE INDEX IF NOT EXISTS idx_fact_location
ON fact_air_quality_health(location_id);

CREATE INDEX IF NOT EXISTS idx_fact_indicator
ON fact_air_quality_health(indicator_key);

-- MATERIALIZED VIEW
DROP MATERIALIZED VIEW IF EXISTS mv_avg_pollution;

CREATE MATERIALIZED VIEW mv_avg_pollution AS
SELECT
    l.geo_place_name,
    d.indicator_name,
    d.indicator_category,
    t.year,
    AVG(f.data_value) AS avg_value
FROM fact_air_quality_health f
JOIN dim_location l
    ON f.location_id = l.location_id
JOIN dim_indicator d
    ON f.indicator_key = d.indicator_key
JOIN dim_time t
    ON f.time_id = t.time_id
GROUP BY
    l.geo_place_name,
    d.indicator_name,
    d.indicator_category,
    t.year;

-- REFRESH MATERIALIZED VIEW
REFRESH MATERIALIZED VIEW mv_avg_pollution;

SELECT *
FROM mv_avg_pollution
LIMIT 5;
-- EXTENSION
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- DATABASE SIZE
SELECT pg_size_pretty(
    pg_database_size('dwh_air_quality')
) AS database_size;

-- PARTITION TABLE
DROP TABLE IF EXISTS fact_partitioned CASCADE;

CREATE TABLE fact_partitioned (
    fact_id BIGINT,
    unique_id BIGINT,
    time_id BIGINT,
    location_id BIGINT,
    indicator_key BIGINT,
    data_value NUMERIC
)
PARTITION BY RANGE (time_id);

-- CHILD PARTITION
CREATE TABLE fact_p1
PARTITION OF fact_partitioned
FOR VALUES FROM (1) TO (50);

CREATE TABLE fact_p2
PARTITION OF fact_partitioned
FOR VALUES FROM (50) TO (100);

CREATE TABLE fact_p3
PARTITION OF fact_partitioned
FOR VALUES FROM (100) TO (1000);

CREATE TABLE fact_p_default
PARTITION OF fact_partitioned
DEFAULT;

-- INSERT DATA KE PARTITION
INSERT INTO fact_partitioned (
    fact_id,
    unique_id,
    time_id,
    location_id,
    indicator_key,
    data_value
)
SELECT
    fact_id,
    unique_id,
    time_id,
    location_id,
    indicator_key,
    data_value
FROM fact_air_quality_health;

-- CEK PARTITION
SELECT
    tableoid::regclass AS partition_name,
    COUNT(*) AS total_rows
FROM fact_partitioned
GROUP BY tableoid
ORDER BY partition_name;

-- BENCHMARK QUERY
EXPLAIN ANALYZE
SELECT
    l.geo_place_name,
    d.indicator_name,
    t.year,
    AVG(f.data_value)
FROM fact_air_quality_health f
JOIN dim_location l
    ON f.location_id = l.location_id
JOIN dim_indicator d
    ON f.indicator_key = d.indicator_key
JOIN dim_time t
    ON f.time_id = t.time_id
GROUP BY
    l.geo_place_name,
    d.indicator_name,
    t.year;

-- BENCHMARK MATERIALIZED VIEW
EXPLAIN ANALYZE
SELECT *
FROM mv_avg_pollution
ORDER BY avg_value DESC;

-- OLAP CUBE QUERY
SELECT
    t.year,
    l.geo_place_name,
    d.indicator_category,
    AVG(f.data_value) AS avg_value
FROM fact_air_quality_health f
JOIN dim_time t
    ON f.time_id = t.time_id
JOIN dim_location l
    ON f.location_id = l.location_id
JOIN dim_indicator d
    ON f.indicator_key = d.indicator_key
GROUP BY CUBE (
    t.year,
    l.geo_place_name,
    d.indicator_category
)
ORDER BY
    t.year,
    l.geo_place_name;

-- OPTIONAL ROLLUP QUERY
SELECT
    t.year,
    d.indicator_category,
    AVG(f.data_value) AS avg_value
FROM fact_air_quality_health f
JOIN dim_time t
    ON f.time_id = t.time_id
JOIN dim_indicator d
    ON f.indicator_key = d.indicator_key
GROUP BY ROLLUP (
    t.year,
    d.indicator_category
)
ORDER BY
    t.year;
