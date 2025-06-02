WITH flight_ref_t as (
    SELECT ao.name AS origin_airport
            , ao.type AS origin_type
            , ao.municipality AS origin_municipality
            , ad.name AS destination_airport
            , ad.type AS destination_type
            , ad.municipality AS destination_municipality
            , f.*
    FROM {{ref ('flight_prep_t')}}  AS f
    LEFT JOIN {{ref ('airport_prep_t')}} AS ao
    ON (f.origin = ao.iata_code)
    LEFT JOIN {{ref ('airport_prep_t')}} AS ad
    ON (f.destination = ad.iata_code)
) SELECT * 
FROM flight_ref_t
