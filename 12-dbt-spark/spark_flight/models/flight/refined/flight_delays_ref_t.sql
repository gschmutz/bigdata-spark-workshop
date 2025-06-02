WITH flight_delays_ref_t AS (
    SELECT year, month, dayOfMonth, dayOfWeek, arrDelay, origin, destination,
        CASE
            WHEN arrDelay > 360 THEN 'Very Long Delays'
            WHEN arrDelay > 120 AND arrDelay < 360 THEN 'Long Delays'
            WHEN arrDelay > 60 AND arrDelay < 120 THEN 'Short Delays'
            WHEN arrDelay > 0 and arrDelay < 60 THEN 'Tolerable Delays'
            WHEN arrDelay = 0 THEN 'No Delays'
            ELSE 'Early'
        END AS flight_delays
            FROM {{ref ('flight_prep_t')}}
) SELECT * 
FROM flight_delays_ref_t
