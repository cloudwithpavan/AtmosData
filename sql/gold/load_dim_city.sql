
-- ============================================================
-- AtmosData: SCD Type 2 - Initial City Load
-- Logic: MERGE
-- ============================================================

MERGE
  `my-project-77-511616.weather_gold_dev.dim_city` T
USING (
  SELECT 'Hyderabad' AS city, 'Telangana' AS state, 'South' AS region
  UNION ALL
  SELECT 'Bengaluru', 'Karnataka', 'South'
  UNION ALL
  SELECT 'Mumbai', 'Maharashtra', 'West'
  UNION ALL
  SELECT 'Delhi', 'Delhi', 'North'
  UNION ALL
  SELECT 'Chennai', 'Tamil Nadu', 'South'
) S
ON T.city = S.city
AND T.is_current = TRUE

WHEN NOT MATCHED THEN
  INSERT (
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
  VALUES (
    GENERATE_UUID(),
    S.city,
    S.state,
    S.region,
    CURRENT_TIMESTAMP(),
    NULL,
    TRUE,
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
  );
