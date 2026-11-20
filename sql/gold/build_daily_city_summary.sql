CREATE TABLE IF NOT EXISTS
  `my-project-77-511616.weather_gold_dev.daily_city_weather`
(
  weather_date DATE,
  city STRING,
  avg_temperature_c FLOAT64,
  min_temperature_c FLOAT64,
  max_temperature_c FLOAT64,
  avg_humidity_pct FLOAT64,
  observation_count INT64,
  refreshed_at_utc TIMESTAMP
)
PARTITION BY weather_date
CLUSTER BY city;

MERGE `my-project-77-511616.weather_gold_dev.daily_city_weather` T
USING (
  SELECT
    DATE(observed_at_utc) AS weather_date,
    city,
    AVG(temperature_c) AS avg_temperature_c,
    MIN(temperature_c) AS min_temperature_c,
    MAX(temperature_c) AS max_temperature_c,
    AVG(humidity_pct) AS avg_humidity_pct,
    COUNT(*) AS observation_count,
    CURRENT_TIMESTAMP() AS refreshed_at_utc
  FROM `my-project-77-511616.weather_silver_dev.weather_observations`
  GROUP BY weather_date, city
) S
ON T.weather_date = S.weather_date AND T.city = S.city
WHEN MATCHED THEN UPDATE SET
  avg_temperature_c = S.avg_temperature_c,
  min_temperature_c = S.min_temperature_c,
  max_temperature_c = S.max_temperature_c,
  avg_humidity_pct = S.avg_humidity_pct,
  observation_count = S.observation_count,
  refreshed_at_utc = S.refreshed_at_utc
WHEN NOT MATCHED THEN INSERT (
  weather_date, city, avg_temperature_c, min_temperature_c,
  max_temperature_c, avg_humidity_pct, observation_count, refreshed_at_utc
) VALUES (
  S.weather_date, S.city, S.avg_temperature_c, S.min_temperature_c,
  S.max_temperature_c, S.avg_humidity_pct, S.observation_count, S.refreshed_at_utc
);
