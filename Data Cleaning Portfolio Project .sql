ATTACH DATABASE 'C:\Users\josep\Documents\aVentaira\Python\openaq_locations.db' AS locations_db;
ATTACH DATABASE 'C:\Users\josep\Documents\aVentaira\Python\openaq_parameters.db' AS parameter_db;
ATTACH DATABASE 'C:\Users\josep\Documents\aVentaira\Python\aqi_guidance.db' AS guidance_db;
ATTACH DATABASE 'C:\Users\josep\Documents\aVentaira\Python\openaq_latest_data.db' AS latest_data_db;


WITH enriched_data AS (
  SELECT 
    l.id AS location_id,
    l.name AS location_name,
    COALESCE(l.city, l.name) AS city,
    l.state,
    l.country,
    l.latitude,
    l.longitude,
    MAX(lm.utc) AS utc_timestamp,

    -- PM2.5: EPA standard is μg/m³ (parameter 2)
    MAX(CASE WHEN p.id = 2 THEN lm.value END) AS "PM2.5",
    MAX(CASE WHEN p.id = 2 THEN p.units END) AS "PM2.5 Unit",

    -- PM10: EPA standard is μg/m³ (parameter 1)
    MAX(CASE WHEN p.id = 1 THEN lm.value END) AS "PM10",
    MAX(CASE WHEN p.id = 1 THEN p.units END) AS "PM10 Unit",

    -- CO: EPA standard is ppm (parameter 8), convert from μg/m³ if needed
    COALESCE(
      MAX(CASE WHEN p.id = 8 THEN lm.value END),
      MAX(CASE WHEN p.id = 4 THEN ROUND(lm.value * 0.000873, 3) END)
    ) AS "CO",
    CASE 
      WHEN MAX(CASE WHEN p.id = 8 THEN lm.value END) IS NOT NULL THEN 'ppm'
      WHEN MAX(CASE WHEN p.id = 4 THEN lm.value END) IS NOT NULL THEN 'ppm'
      ELSE NULL
    END AS "CO Unit",

    -- NO2: EPA standard is ppb (parameter 7), convert from μg/m³ if needed  
    COALESCE(
      MAX(CASE WHEN p.id = 7 THEN lm.value END),
      MAX(CASE WHEN p.id = 5 THEN ROUND(lm.value * 0.532, 3) END)
    ) AS "NO2",
    CASE 
      WHEN MAX(CASE WHEN p.id = 7 THEN lm.value END) IS NOT NULL THEN 'ppb'
      WHEN MAX(CASE WHEN p.id = 5 THEN lm.value END) IS NOT NULL THEN 'ppb'
      ELSE NULL
    END AS "NO2 Unit",

    -- O3: EPA standard is ppb (parameter 10), convert from μg/m³ if needed
    COALESCE(
      MAX(CASE WHEN p.id = 10 THEN lm.value END),
      MAX(CASE WHEN p.id = 3 THEN ROUND(lm.value * 0.508, 3) END)
    ) AS "O3",
    CASE 
      WHEN MAX(CASE WHEN p.id = 10 THEN lm.value END) IS NOT NULL THEN 'ppb'
      WHEN MAX(CASE WHEN p.id = 3 THEN lm.value END) IS NOT NULL THEN 'ppb'
      ELSE NULL
    END AS "O3 Unit",

    -- SO2: EPA standard is ppb (parameter 9), convert from μg/m³ if needed
    COALESCE(
      MAX(CASE WHEN p.id = 9 THEN lm.value END),
      MAX(CASE WHEN p.id = 6 THEN ROUND(lm.value * 0.383, 3) END)
    ) AS "SO2",
    CASE 
      WHEN MAX(CASE WHEN p.id = 9 THEN lm.value END) IS NOT NULL THEN 'ppb'
      WHEN MAX(CASE WHEN p.id = 6 THEN lm.value END) IS NOT NULL THEN 'ppb'
      ELSE NULL
    END AS "SO2 Unit",

    MAX(CASE WHEN p.id IN (11) THEN lm.value END) AS "BC",
    MAX(CASE WHEN p.id IN (11) THEN p.units  END) AS "BC Unit",

    MAX(CASE WHEN p.id IN (19) THEN lm.value END) AS "VOC",
    MAX(CASE WHEN p.id IN (19) THEN p.units  END) AS "VOC Unit",

    MAX(CASE WHEN p.id IN (21) THEN lm.value END) AS "NH3",
    MAX(CASE WHEN p.id IN (21) THEN p.units  END) AS "NH3 Unit",

    MAX(CASE WHEN p.id IN (27) THEN lm.value END) AS "NO",
    MAX(CASE WHEN p.id IN (27) THEN p.units  END) AS "NO Unit",

    MAX(CASE WHEN p.id IN (19843) THEN lm.value END) AS "NOx",
    MAX(CASE WHEN p.id IN (19843) THEN p.units  END) AS "NOx Unit",

    MAX(asd.max_aqi) AS max_aqi,
    MAX(pp.name) AS max_aqi_parameter,

    CASE 
      WHEN MAX(asd.max_aqi) BETWEEN 0 AND 50 THEN 'Good'
      WHEN MAX(asd.max_aqi) BETWEEN 51 AND 100 THEN 'Moderate'
      WHEN MAX(asd.max_aqi) BETWEEN 101 AND 150 THEN 'Unhealthy for Sensitive Groups'
      WHEN MAX(asd.max_aqi) BETWEEN 151 AND 200 THEN 'Unhealthy'
      WHEN MAX(asd.max_aqi) BETWEEN 201 AND 300 THEN 'Very Unhealthy'
      WHEN MAX(asd.max_aqi) >= 301 THEN 'Hazardous'
      ELSE 'Unknown'
    END AS max_aqi_category,

    l.provider,

    -- Track which pollutants were converted from μg/m³ to EPA standards
    CASE 
      WHEN (MAX(CASE WHEN p.id = 4 THEN lm.value END) IS NOT NULL AND MAX(CASE WHEN p.id = 8 THEN lm.value END) IS NULL) OR
           (MAX(CASE WHEN p.id = 5 THEN lm.value END) IS NOT NULL AND MAX(CASE WHEN p.id = 7 THEN lm.value END) IS NULL) OR  
           (MAX(CASE WHEN p.id = 3 THEN lm.value END) IS NOT NULL AND MAX(CASE WHEN p.id = 10 THEN lm.value END) IS NULL) OR
           (MAX(CASE WHEN p.id = 6 THEN lm.value END) IS NOT NULL AND MAX(CASE WHEN p.id = 9 THEN lm.value END) IS NULL)
      THEN TRIM(
        (CASE WHEN MAX(CASE WHEN p.id = 4 THEN lm.value END) IS NOT NULL AND MAX(CASE WHEN p.id = 8 THEN lm.value END) IS NULL THEN 'CO, ' ELSE '' END) ||
        (CASE WHEN MAX(CASE WHEN p.id = 5 THEN lm.value END) IS NOT NULL AND MAX(CASE WHEN p.id = 7 THEN lm.value END) IS NULL THEN 'NO2, ' ELSE '' END) ||
        (CASE WHEN MAX(CASE WHEN p.id = 3 THEN lm.value END) IS NOT NULL AND MAX(CASE WHEN p.id = 10 THEN lm.value END) IS NULL THEN 'O3, ' ELSE '' END) ||
        (CASE WHEN MAX(CASE WHEN p.id = 6 THEN lm.value END) IS NOT NULL AND MAX(CASE WHEN p.id = 9 THEN lm.value END) IS NULL THEN 'SO2, ' ELSE '' END), 
        ', '
      )
      ELSE NULL
    END AS converted_pollutants

  FROM latest_data_db.latest_measurements lm
  JOIN locations_db.locations l 
    ON lm.locations_id = l.id
  JOIN parameter_db.parameters p 
    ON lm.parameter_id = p.id
  LEFT JOIN (
    SELECT asd_inner.locations_id, asd_inner.max_aqi, asd_inner.parameter_id,
           ROW_NUMBER() OVER (PARTITION BY asd_inner.locations_id ORDER BY asd_inner.utc DESC) as rn
    FROM latest_data_db.aqi_summary_detailed asd_inner
  ) asd ON lm.locations_id = asd.locations_id AND asd.rn = 1
  LEFT JOIN parameter_db.parameters pp
    ON asd.parameter_id = pp.id

  WHERE p.id IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 19, 21, 27, 19843)
  GROUP BY l.id, l.name, l.city, l.state, l.country, l.latitude, l.longitude, l.provider
),

-- Add desired cities data using their nearest location's air quality data
-- Exclude desired cities that already exist in the locations table city column
desired_cities_data AS (
  SELECT 
    dc.nearest_location_id AS location_id,
    dc.name AS location_name,  -- Use desired city name for location_name
    dc.name AS city,           -- Use desired city name for city
    ed.state,
    ed.country,
    ed.latitude,
    ed.longitude,
    ed.utc_timestamp,
    ed."PM10", ed."PM10 Unit",
    ed."PM2.5", ed."PM2.5 Unit",
    ed."CO", ed."CO Unit",
    ed."NO2", ed."NO2 Unit",
    ed."O3", ed."O3 Unit",
    ed."SO2", ed."SO2 Unit",
    ed."BC", ed."BC Unit",
    ed."VOC", ed."VOC Unit",
    ed."NH3", ed."NH3 Unit",
    ed."NO", ed."NO Unit",
    ed."NOx", ed."NOx Unit",
    ed.max_aqi,
    ed.max_aqi_parameter,
    ed.max_aqi_category,
    ed.provider,
    ed.converted_pollutants
  FROM locations_db.desired_cities dc
  JOIN enriched_data ed ON dc.nearest_location_id = ed.location_id
  WHERE dc.name NOT IN (
    SELECT DISTINCT COALESCE(l.city, l.name)
    FROM locations_db.locations l
    WHERE l.city IS NOT NULL
  )
),

-- Combine original locations and desired cities
combined_data AS (
  SELECT * FROM enriched_data
  UNION ALL
  SELECT * FROM desired_cities_data
),

city_state_avg AS (
  SELECT 
    CASE
      WHEN city IS NOT NULL AND state IS NOT NULL THEN city || ', ' || state
      WHEN city IS NOT NULL THEN city
      WHEN state IS NOT NULL THEN state
      ELSE 'Unknown'
    END AS location_key,
    CAST(AVG(max_aqi) AS INTEGER) AS average_aqi
  FROM combined_data
  GROUP BY location_key
)

SELECT 
  cd.location_id,
  cd.location_name,
  cd.city,
  cd.state,
  cd.country,
  cd.latitude,
  cd.longitude,
  cd.utc_timestamp AS utc,
  cd."PM10", cd."PM10 Unit",
  cd."PM2.5", cd."PM2.5 Unit",
  cd."CO", cd."CO Unit",
  cd."NO2", cd."NO2 Unit",
  cd."O3", cd."O3 Unit",
  cd."SO2", cd."SO2 Unit",
  cd."BC", cd."BC Unit",
  cd."VOC", cd."VOC Unit",
  cd."NH3", cd."NH3 Unit",
  cd."NO", cd."NO Unit",
  cd."NOx", cd."NOx Unit",
  cd.max_aqi,
  cd.max_aqi_parameter,
  cd.max_aqi_category,

  -- Outdoor Activities
  CASE
    WHEN cd.max_aqi <= 50 THEN 'Perfect for outdoor exercise and recreation. Great for opening windows to bring in fresh air.'
    WHEN cd.max_aqi <= 100 THEN 'Safe for most people; sensitive individuals may reduce strenuous activity. Good for walking, biking, or errands outside.'
    WHEN cd.max_aqi <= 150 THEN 'Healthy people can be active outside, but limit prolonged exertion. Sensitive groups (kids, elderly, asthmatics) should stay indoors during peak hours.'
    WHEN cd.max_aqi <= 200 THEN 'Limit time outside for everyone; avoid intense workouts. Postpone outdoor plans if possible.'
    WHEN cd.max_aqi <= 300 THEN 'Avoid outdoor activity unless absolutely necessary. Schools and workplaces should move activities indoors.'
    WHEN cd.max_aqi > 300 THEN 'Stay indoors — outdoor activity is dangerous. Evacuate if advised by local authorities.'
    ELSE 'No outdoor activity guidance available'
  END AS outdoor_activities,

  -- Indoor Air
  CASE
    WHEN cd.max_aqi <= 50 THEN 'No action needed — air quality is excellent. Optional: Use this time to air out the house.'
    WHEN cd.max_aqi <= 100 THEN 'Still fine to open windows briefly. Optional: Use air purifier if you are sensitive to pollutants.'
    WHEN cd.max_aqi <= 150 THEN 'Keep windows mostly closed. Run air purifiers in main living areas and bedrooms.'
    WHEN cd.max_aqi <= 200 THEN 'Keep windows shut and run air purifiers. Avoid indoor pollution sources (candles, frying, smoking).'
    WHEN cd.max_aqi <= 300 THEN 'Run HEPA-filter air purifiers 24/7. Seal windows/doors with weather stripping or towels.'
    WHEN cd.max_aqi > 300 THEN 'Create a clean air room with HEPA filtration. Keep HVAC systems on recirculate mode.'
    ELSE 'No indoor air guidance available'
  END AS indoor_air,

  -- Health Tips
  CASE
    WHEN cd.max_aqi <= 50 THEN 'Ideal for everyone, including sensitive groups. No protective measures required.'
    WHEN cd.max_aqi <= 100 THEN 'Mild risk for those with asthma or heart conditions. Monitor symptoms if sensitive to air quality.'
    WHEN cd.max_aqi <= 150 THEN 'Have medications (e.g., inhalers) ready. Check air quality apps before going out.'
    WHEN cd.max_aqi <= 200 THEN 'Consider wearing a KN95/N95 mask outdoors. Stay hydrated and watch for breathing issues.'
    WHEN cd.max_aqi <= 300 THEN 'Use masks when stepping outside. Vulnerable people should remain indoors entirely.'
    WHEN cd.max_aqi > 300 THEN 'Monitor symptoms — seek medical help if breathing worsens. Check on vulnerable neighbors and family members.'
    ELSE 'No health guidance available'
  END AS health_tips,

  cd.provider,
  cd.converted_pollutants

FROM combined_data cd
LEFT JOIN city_state_avg csa
  ON (
       CASE
         WHEN cd.city IS NOT NULL AND cd.state IS NOT NULL THEN cd.city || ', ' || cd.state
         WHEN cd.city IS NOT NULL THEN cd.city
         WHEN cd.state IS NOT NULL THEN cd.state
         ELSE 'Unknown'
       END
     ) = csa.location_key
WHERE cd.max_aqi IS NOT NULL AND cd.max_aqi > 0

LIMIT 100;

