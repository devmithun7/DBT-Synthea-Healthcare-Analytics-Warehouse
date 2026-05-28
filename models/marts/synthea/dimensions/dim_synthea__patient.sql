{{
    config(
        tags=['daily']
    )
}}

select
    {{ synthea_surrogate_key(['patient_id', 'effective_from']) }} as patient_key,
    patient_id,
    first_name,
    last_name,
    date_of_birth,
    patient_gender,
    race,
    ethnicity,
    payer_id,
    payer_name,
    effective_from,
    effective_to,
    is_current,
    scd2_version,
    {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_loaded_at
from {{ ref('int_synthea__patient_insurance_periods') }}
