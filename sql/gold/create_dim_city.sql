
-- ============================================================
-- AtmosData: City Dimension Table
-- SCD Type 2
-- ============================================================

CREATE TABLE IF NOT EXISTS
  `my-project-77-511616.weather_gold_dev.dim_city`
(
  city_key STRING,
  city STRING,
  state STRING,
  region STRING,
  effective_from TIMESTAMP,
  effective_to TIMESTAMP,
  is_current BOOL,
  created_at_utc TIMESTAMP,
  updated_at_utc TIMESTAMP
)
CLUSTER BY city, is_current;
