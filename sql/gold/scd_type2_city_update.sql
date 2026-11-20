
-- ============================================================
-- AtmosData: SCD Type 2 - City Metadata Change
-- Test scenario: Hyderabad region South -> South-Central
-- ============================================================

DECLARE change_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP();

-- Identify cities requiring a new version.
CREATE TEMP TABLE city_changes AS
SELECT
  city,
  state,
  'South-Central' AS new_region
FROM
  `my-project-77-511616.weather_gold_dev.dim_city`
WHERE
  city = 'Hyderabad'
  AND is_current = TRUE
  AND region != 'South-Central';

BEGIN TRANSACTION;

-- Step 1: Expire the old version.
UPDATE
  `my-project-77-511616.weather_gold_dev.dim_city`
SET
  effective_to = change_timestamp,
  is_current = FALSE,
  updated_at_utc = change_timestamp
WHERE
  city = 'Hyderabad'
  AND is_current = TRUE
  AND EXISTS (SELECT 1 FROM city_changes);

-- Step 2: Insert the new version.
INSERT INTO
  `my-project-77-511616.weather_gold_dev.dim_city`
(
  city_key,
  city,
  state,
  region,
  effective_from,
  effective_to,
  is_current,
  created_at_utc,
  updated_at_utc
)
SELECT
  GENERATE_UUID(),
  city,
  state,
  new_region,
  change_timestamp,
  NULL,
  TRUE,
  change_timestamp,
  change_timestamp
FROM city_changes;

COMMIT TRANSACTION;
