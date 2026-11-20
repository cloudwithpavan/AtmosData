CREATE TABLE IF NOT EXISTS
  `my-project-77-511616.weather_bronze_dev.weather_observations`
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
