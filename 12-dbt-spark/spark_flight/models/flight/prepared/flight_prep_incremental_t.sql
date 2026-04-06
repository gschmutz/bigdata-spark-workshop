{{ config(
    materialized='incremental',
    unique_key='flightNum'
) }}

WITH flight_prep_incremental_t AS (
    SELECT year,
        month,
        dayOfMonth,
        dayOfWeek,
        depTime,
        crsDepTime,
        arrTime,
        crsArrTime,
        uniqueCarrier,
        flightNum,
        tailNum,
        actualElapsedTime,
        crsElapsedTime,
        airTime,
        arrDelay,
        depDelay,
        origin,
        destination,
        distance,
        taxiIn,
        taxiOut,
        cancelled,
        cancellationCode,
        diverted,
        carrierDelay,
        weatherDelay,
        nasDelay,
        securityDelay,
        lateAircraftDelay
    FROM {{ source('flight_db', 'flight_raw_t') }}

    {% if is_incremental() %}
    WHERE year > (SELECT MAX(year) FROM {{ this }})
       OR (year = (SELECT MAX(year) FROM {{ this }})
           AND month > (SELECT MAX(month) FROM {{ this }}))
    {% endif %}
) SELECT *
FROM flight_prep_incremental_t
