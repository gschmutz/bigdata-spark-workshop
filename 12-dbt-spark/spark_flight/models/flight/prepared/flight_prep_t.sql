WITH flight_prep_t AS (
   SELECT year, 
        month,
        CAST(dayOfMonth AS INT) AS dayOfMonth,
        CAST(dayOfWeek AS INT) AS dayOfWeek,
        CAST(depTime AS INT) AS depTime,
        CAST(crsDepTime AS INT) AS crsDepTime,
        CAST(arrTime AS INT) AS arrTime,
        CAST(crsArrTime AS INT) AS crsArrTime,
        uniqueCarrier, 
        flightNum, 
        tailNum, 
        CAST(actualElapsedTime AS INT) AS actualElapsedTime,
        CAST(crsElapsedTime AS INT) AS crsElapsedTime, 
        CAST(airTime AS INT) AS airTime, 
        CAST(arrDelay AS INT) AS arrDelay,
        CAST(depDelay AS INT) AS depDelay,
        origin, 
        destination, 
        CAST(distance AS INT) AS distance, 
        CAST(taxiIn AS INT) AS taxiIn, 
        CAST(taxiOut AS INT) AS taxiOut, 
        CASE WHEN cancelled IS NULL 
                THEN 0 
            WHEN cancelled = 'N' 
                THEN 0
            ELSE 1 
        END AS cancelled,         
        cancellationCode, 
        CASE WHEN diverted IS NULL 
                THEN 0 
            WHEN diverted = 'N' 
                THEN 0
            ELSE 1 
        END AS diverted,         
        CASE WHEN carrierDelay IS NULL
                THEN NULL 
            WHEN diverted = 'NA' 
                THEN NULL
            ELSE CAST(carrierDelay AS INT)
        END AS carrierDelay,
        CASE WHEN weatherDelay IS NULL
                THEN NULL 
            WHEN weatherDelay = 'NA' 
                THEN NULL
            ELSE CAST(weatherDelay AS INT)
        END AS weatherDelay,
        CASE WHEN nasDelay IS NULL
                THEN NULL 
            WHEN nasDelay = 'NA' 
                THEN NULL
            ELSE CAST(nasDelay AS INT)
        END AS nasDelay,
        CASE WHEN securityDelay IS NULL
                THEN NULL 
            WHEN securityDelay = 'NA' 
                THEN NULL
            ELSE CAST(securityDelay AS INT)
        END AS securityDelay,
        CASE WHEN lateAircraftDelay IS NULL
                THEN NULL 
            WHEN lateAircraftDelay = 'NA' 
                THEN NULL
            ELSE CAST(lateAircraftDelay AS INT)
        END AS lateAircraftDelay
    from {{ source('flight_db', 'flight_raw_t') }} 
)select * 
from flight_prep_t

