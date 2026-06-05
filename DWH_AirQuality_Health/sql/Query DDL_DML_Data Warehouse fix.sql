-- CLEANUP OBJECT OLAP LAMA

DROP TABLE IF EXISTS fact_air_quality_health CASCADE;
DROP TABLE IF EXISTS dim_time CASCADE;
DROP TABLE IF EXISTS dim_location CASCADE;
DROP TABLE IF EXISTS dim_indicator CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_avg_pollution CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_olap_base CASCADE;
DROP TABLE IF EXISTS public.fact_partitioned CASCADE;
-- DROP FOREIGN KEY LAMA DULU

ALTER TABLE fact_air_quality_health
DROP CONSTRAINT IF EXISTS fk_time;

ALTER TABLE fact_air_quality_health
DROP CONSTRAINT IF EXISTS fk_location;

ALTER TABLE fact_air_quality_health
DROP CONSTRAINT IF EXISTS fk_indicator;

ALTER TABLE fact_air_quality_health
DROP CONSTRAINT IF EXISTS fk_batch;

-- PRIMARY KEY

ALTER TABLE dim_time
DROP CONSTRAINT IF EXISTS dim_time_pkey;

ALTER TABLE dim_time
DROP CONSTRAINT IF EXISTS pk_dim_time;

ALTER TABLE dim_time
ADD CONSTRAINT pk_dim_time PRIMARY KEY (time_id);


ALTER TABLE dim_location
DROP CONSTRAINT IF EXISTS dim_location_pkey;

ALTER TABLE dim_location
DROP CONSTRAINT IF EXISTS pk_dim_location;

ALTER TABLE dim_location
ADD CONSTRAINT pk_dim_location PRIMARY KEY (location_id);


ALTER TABLE dim_indicator
DROP CONSTRAINT IF EXISTS dim_indicator_pkey;

ALTER TABLE dim_indicator
DROP CONSTRAINT IF EXISTS pk_dim_indicator;

ALTER TABLE dim_indicator
ADD CONSTRAINT pk_dim_indicator PRIMARY KEY (indicator_key);


ALTER TABLE dim_batch
DROP CONSTRAINT IF EXISTS dim_batch_pkey;

ALTER TABLE dim_batch
DROP CONSTRAINT IF EXISTS pk_dim_batch;

ALTER TABLE dim_batch
ADD CONSTRAINT pk_dim_batch PRIMARY KEY (batch_id);


ALTER TABLE fact_air_quality_health
DROP CONSTRAINT IF EXISTS fact_air_quality_health_pkey;

ALTER TABLE fact_air_quality_health
DROP CONSTRAINT IF EXISTS pk_fact_air_quality_health;

ALTER TABLE fact_air_quality_health
ADD CONSTRAINT pk_fact_air_quality_health PRIMARY KEY (fact_id);

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


ALTER TABLE fact_air_quality_health
ADD CONSTRAINT fk_batch
FOREIGN KEY (batch_id)
REFERENCES dim_batch(batch_id);

-- EXTENSION

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- INDEX

CREATE INDEX IF NOT EXISTS idx_fact_time
ON fact_air_quality_health(time_id);

CREATE INDEX IF NOT EXISTS idx_fact_location
ON fact_air_quality_health(location_id);

CREATE INDEX IF NOT EXISTS idx_fact_indicator
ON fact_air_quality_health(indicator_key);

CREATE INDEX IF NOT EXISTS idx_fact_batch
ON fact_air_quality_health(batch_id);

CREATE INDEX IF NOT EXISTS idx_dim_indicator_category
ON dim_indicator(indicator_category);

CREATE INDEX IF NOT EXISTS idx_dim_location_geo_type
ON dim_location(geo_type_name);

CREATE INDEX IF NOT EXISTS idx_location_name_trgm
ON dim_location
USING gin (geo_place_name gin_trgm_ops);

-- MATERIALIZED VIEW BASE OLAP

CREATE MATERIALIZED VIEW mv_olap_base AS
SELECT
    f.fact_id,
    f.unique_id,
    f.data_value,
    f.batch_id,
    b.batch_name,
    b.start_year AS batch_start_year,
    b.end_year AS batch_end_year,

    t.time_id,
    t.start_date,
    t.year,
    t.month,
    t.quarter,
    t.time_period,

    l.location_id,
    l.geo_type_name,
    l.geo_join_id,
    l.geo_place_name,

    d.indicator_key,
    d.source_indicator_id,
    d.indicator_name,
    d.indicator_category,

    CASE
        WHEN MAX(f.data_value) OVER (PARTITION BY f.indicator_key)
             >
             MIN(f.data_value) OVER (PARTITION BY f.indicator_key)
        THEN
            (
                (f.data_value - MIN(f.data_value) OVER (PARTITION BY f.indicator_key))
                /
                NULLIF(
                    MAX(f.data_value) OVER (PARTITION BY f.indicator_key)
                    -
                    MIN(f.data_value) OVER (PARTITION BY f.indicator_key),
                    0
                )
            ) * 100
        ELSE 0
    END AS risk_score

FROM fact_air_quality_health f
JOIN dim_time t
    ON f.time_id = t.time_id
JOIN dim_location l
    ON f.location_id = l.location_id
JOIN dim_indicator d
    ON f.indicator_key = d.indicator_key
JOIN dim_batch b
    ON f.batch_id = b.batch_id;


-- MATERIALIZED VIEW AVG POLLUTION

CREATE MATERIALIZED VIEW mv_avg_pollution AS
SELECT
    geo_place_name,
    geo_type_name,
    indicator_name,
    indicator_category,
    year,
    batch_name,
    AVG(data_value) AS avg_value,
    AVG(risk_score) AS avg_risk_score,
    COUNT(*) AS total_data
FROM mv_olap_base
GROUP BY
    geo_place_name,
    geo_type_name,
    indicator_name,
    indicator_category,
    year,
    batch_name;


-- DATABASE SIZE

SELECT pg_size_pretty(
    pg_database_size('dwh_air_quality')
) AS database_size;

-- PARTITION TABLE

CREATE TABLE fact_partitioned (
    fact_id BIGINT,
    unique_id BIGINT,
    time_id BIGINT,
    location_id BIGINT,
    indicator_key BIGINT,
    batch_id BIGINT,
    data_value NUMERIC
)
PARTITION BY RANGE (time_id);


CREATE TABLE fact_p1
PARTITION OF fact_partitioned
FOR VALUES FROM (1) TO (20);


CREATE TABLE fact_p2
PARTITION OF fact_partitioned
FOR VALUES FROM (20) TO (40);


CREATE TABLE fact_p3
PARTITION OF fact_partitioned
FOR VALUES FROM (40) TO (100);


CREATE TABLE fact_p_default
PARTITION OF fact_partitioned
DEFAULT;


INSERT INTO fact_partitioned (
    fact_id,
    unique_id,
    time_id,
    location_id,
    indicator_key,
    batch_id,
    data_value
)
SELECT
    fact_id,
    unique_id,
    time_id,
    location_id,
    indicator_key,
    batch_id,
    data_value
FROM fact_air_quality_health;

-- CEK PARTITION

SELECT
    tableoid::regclass AS partition_name,
    COUNT(*) AS total_rows
FROM fact_partitioned
GROUP BY tableoid
ORDER BY partition_name;

-- BENCHMARK QUERY LANGSUNG

EXPLAIN ANALYZE
SELECT
    l.geo_place_name,
    l.geo_type_name,
    d.indicator_name,
    d.indicator_category,
    t.year,
    b.batch_name,
    AVG(f.data_value) AS avg_value,
    COUNT(*) AS total_data
FROM fact_air_quality_health f
JOIN dim_location l
    ON f.location_id = l.location_id
JOIN dim_indicator d
    ON f.indicator_key = d.indicator_key
JOIN dim_time t
    ON f.time_id = t.time_id
JOIN dim_batch b
    ON f.batch_id = b.batch_id
GROUP BY
    l.geo_place_name,
    l.geo_type_name,
    d.indicator_name,
    d.indicator_category,
    t.year,
    b.batch_name;

-- BENCHMARK MATERIALIZED VIEW
EXPLAIN ANALYZE
SELECT *
FROM mv_avg_pollution
ORDER BY avg_risk_score DESC;

-- OLAP CUBE QUERY

SELECT
    year,
    geo_place_name,
    indicator_category,
    batch_name,
    AVG(data_value) AS avg_value,
    AVG(risk_score) AS avg_risk_score
FROM mv_olap_base
GROUP BY CUBE (
    year,
    geo_place_name,
    indicator_category,
    batch_name
)
ORDER BY
    year,
    geo_place_name,
    indicator_category,
    batch_name;

-- OPTIONAL ROLLUP QUERY

SELECT
    year,
    indicator_category,
    AVG(data_value) AS avg_value,
    AVG(risk_score) AS avg_risk_score
FROM mv_olap_base
GROUP BY ROLLUP (
    year,
    indicator_category
)
ORDER BY
    year,
    indicator_category;

SELECT COUNT(*) FROM dim_time;
SELECT COUNT(*) FROM dim_location;
SELECT COUNT(*) FROM dim_indicator;
SELECT COUNT(*) FROM dim_batch;
SELECT COUNT(*) FROM fact_air_quality_health;

SELECT
    conname,
    contype
FROM pg_constraint
WHERE conrelid =
'fact_air_quality_health'::regclass;

SELECT
    indexname
FROM pg_indexes
WHERE schemaname='public';

SELECT COUNT(*)
FROM mv_olap_base;

SELECT COUNT(*)
FROM mv_avg_pollution;

SELECT *
FROM mv_avg_pollution
LIMIT 5;

SELECT
    tableoid::regclass AS partition_name,
    COUNT(*) AS total_rows
FROM fact_partitioned
GROUP BY tableoid
ORDER BY partition_name;


SELECT *
FROM pg_extension;

SELECT extname
FROM pg_extension;

EXPLAIN ANALYZE
SELECT
    l.geo_place_name,
    d.indicator_name,
    t.year,
    AVG(f.data_value)
FROM fact_air_quality_health f
...

EXPLAIN ANALYZE
SELECT *
FROM mv_avg_pollution
ORDER BY avg_risk_score DESC;

SELECT
    year,
    geo_place_name,
    indicator_category,
    batch_name,
    AVG(data_value)
FROM mv_olap_base
GROUP BY CUBE(...)
LIMIT 20;

SELECT extname FROM pg_extension;

SELECT indexname
FROM pg_indexes
WHERE schemaname='public';

SELECT
    conname,
    contype
FROM pg_constraint
WHERE conrelid='fact_air_quality_health'::regclass;
