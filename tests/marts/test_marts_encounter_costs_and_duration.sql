with invalid_rows as (
    select
        'fct_encounters.total_claim_cost' as issue,
        total_claim_cost::float as value
    from {{ ref('fct_synthea__encounters') }}
    where total_claim_cost < 0

    union all

    select
        'fct_encounters.encounter_payer_coverage' as issue,
        encounter_payer_coverage::float as value
    from {{ ref('fct_synthea__encounters') }}
    where encounter_payer_coverage < 0

    union all

    select
        'fct_encounters.patient_out_of_pocket' as issue,
        patient_out_of_pocket::float as value
    from {{ ref('fct_synthea__encounters') }}
    where patient_out_of_pocket < 0

    union all

    select
        'fct_encounters.duration_hours' as issue,
        duration_hours::float as value
    from {{ ref('fct_synthea__encounters') }}
    where duration_hours < 0
       or duration_hours > 1000
)

select *
from invalid_rows
