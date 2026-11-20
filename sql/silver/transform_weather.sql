CREATE TABLE IF NOT EXISTS
  `my-project-77-511616.weather_silver_dev.weather_observations`
(
  city STRING,
  observed_at_utc TIMESTAMP,
  temperature_c FLOAT64,
  feels_like_c FLOAT64,
  humidity_pct INT64,
  pressure_hpa INT64,
  weather_main STRING,
  weather_description STRING,
  wind_speed_mps FLOAT64,
  cloudiness_pct INT64,
  source_object STRING,
  loaded_at_utc TIMESTAMP
)
PARTITION BY DATE(observed_at_utc)
CLUSTER BY city;

MERGE `my-project-77-511616.weather_silver_dev.weather_observations` T
USING (
  SELECT
    city, observed_at_utc, temperature_c, feels_like_c, humidity_pct,
    pressure_hpa, weather_main, weather_description, wind_speed_mps,
    cloudiness_pct, source_object, loaded_at_utc
  FROM `my-project-77-511616.weather_bronze_dev.weather_observations`
  WHERE city IS NOT NULL AND observed_at_utc IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY city, observed_at_utc
    ORDER BY loaded_at_utc DESC
  ) = 1
) S
ON T.city = S.city AND T.observed_at_utc = S.observed_at_utc
WHEN MATCHED THEN UPDATE SET
  temperature_c = S.temperature_c,
  feels_like_c = S.feels_like_c,
  humidity_pct = S.humidity_pct,
  pressure_hpa = S.pressure_hpa,
  weather_main = S.weather_main,
  weather_description = S.weather_description,
  wind_speed_mps = S.wind_speed_mps,
  cloudiness_pct = S.cloudiness_pct,
  source_object = S.source_object,
  loaded_at_utc = S.loaded_at_utc
WHEN NOT MATCHED THEN INSERT (
  city, observed_at_utc, temperature_c, feels_like_c, humidity_pct,
  pressure_hpa, weather_main, weather_description, wind_speed_mps,
  cloudiness_pct, source_object, loaded_at_utc
) VALUES (
  S.city, S.observed_at_utc, S.temperature_c, S.feels_like_c, S.humidity_pct,
  S.pressure_hpa, S.weather_main, S.weather_description, S.wind_speed_mps,
  S.cloudiness_pct, S.source_object, S.loaded_at_utc
);
