
-- ============================================================
-- AtmosData: Silver Layer
-- Purpose: Validate, deduplicate and upsert weather observations
-- ============================================================

CREATE TABLE IF NOT EXISTS
  `my-project-77-511616.weather_silver_dev.weather_observations`
(
  city STRING,
  latitude FLOAT64,
  longitude FLOAT64,
  observed_at_utc TIMESTAMP,
  provider_timestamp INT64,
  temperature_c FLOAT64,
  feels_like_c FLOAT64,
  humidity_pct INT64,
  pressure_hpa INT64,
  weather_main STRING,
  weather_description STRING,
  wind_speed_mps FLOAT64,
  cloudiness_pct INT64,
  source_bucket STRING,
  source_object STRING,
  source_generation STRING,
  loaded_at_utc TIMESTAMP
)
PARTITION BY DATE(loaded_at_utc)
CLUSTER BY city;

MERGE
  `my-project-77-511616.weather_silver_dev.weather_observations` T
USING (
  SELECT
    city,
    latitude,
    longitude,
    observed_at_utc,
    provider_timestamp,
    temperature_c,
    feels_like_c,
    humidity_pct,
    pressure_hpa,
    weather_main,
    weather_description,
    wind_speed_mps,
    cloudiness_pct,
    source_bucket,
    source_object,
    source_generation,
    loaded_at_utc
  FROM
    `my-project-77-511616.weather_bronze_dev.weather_observations`
  WHERE
    city IS NOT NULL
    AND provider_timestamp IS NOT NULL
    AND temperature_c BETWEEN -100 AND 70
    AND humidity_pct BETWEEN 0 AND 100
    AND pressure_hpa > 0
    AND cloudiness_pct BETWEEN 0 AND 100
    AND latitude BETWEEN -90 AND 90
    AND longitude BETWEEN -180 AND 180
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY city, provider_timestamp
    ORDER BY loaded_at_utc DESC, source_generation DESC
  ) = 1
) S
ON T.city = S.city
AND T.provider_timestamp = S.provider_timestamp

WHEN MATCHED AND S.loaded_at_utc >= T.loaded_at_utc THEN
  UPDATE SET
    latitude = S.latitude,
    longitude = S.longitude,
    observed_at_utc = S.observed_at_utc,
    temperature_c = S.temperature_c,
    feels_like_c = S.feels_like_c,
    humidity_pct = S.humidity_pct,
    pressure_hpa = S.pressure_hpa,
    weather_main = S.weather_main,
    weather_description = S.weather_description,
    wind_speed_mps = S.wind_speed_mps,
    cloudiness_pct = S.cloudiness_pct,
    source_bucket = S.source_bucket,
    source_object = S.source_object,
    source_generation = S.source_generation,
    loaded_at_utc = S.loaded_at_utc

WHEN NOT MATCHED THEN
  INSERT (
    city,
    latitude,
    longitude,
    observed_at_utc,
    provider_timestamp,
    temperature_c,
    feels_like_c,
    humidity_pct,
    pressure_hpa,
    weather_main,
    weather_description,
    wind_speed_mps,
    cloudiness_pct,
    source_bucket,
    source_object,
    source_generation,
    loaded_at_utc
  )
  VALUES (
    S.city,
    S.latitude,
    S.longitude,
    S.observed_at_utc,
    S.provider_timestamp,
    S.temperature_c,
    S.feels_like_c,
    S.humidity_pct,
    S.pressure_hpa,
    S.weather_main,
    S.weather_description,
    S.wind_speed_mps,
    S.cloudiness_pct,
    S.source_bucket,
    S.source_object,
    S.source_generation,
    S.loaded_at_utc
  );
