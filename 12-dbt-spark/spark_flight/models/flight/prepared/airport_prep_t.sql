WITH airport_prep_t AS (
   SELECT 
        CAST (id AS INT) as id, 
        ident,
        type,
        name,
        CAST (latitude_deg AS DOUBLE) as latitude_degree,
        CAST (longitude_deg AS DOUBLE) as longitude_degree,
        CAST (elevation_ft AS INT) as elevation_feet,
        CASE WHEN continent IS NULL
                THEN NULL
            ELSE continent
        END AS continent,
        iso_country,
        iso_region,
        municipality,
        CASE WHEN scheduled_service IS NULL
                THEN NULL
            WHEN scheduled_service = 'no'
                THEN 0
            ELSE 1
        END AS scheduled_service,
        gps_code,
        iata_code,
        local_code,
        home_link,
        wikipedia_link,
        keywords
    FROM {{ source('flight_db', 'airport_raw_t') }}
) SELECT * 
FROM airport_prep_t
