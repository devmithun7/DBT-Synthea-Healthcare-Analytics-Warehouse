{{
    config(
        tags=['daily']
    )
}}

with readmission_base as (

    select
        {{ synthea_surrogate_key(['r.index_encounter_id', 'r.readmit_encounter_id']) }} as readmission_key,
        r.index_encounter_id,
        r.readmit_encounter_id,
        {{ synthea_surrogate_key(['pip.patient_id', 'pip.effective_from']) }} as patient_key,
        {{ synthea_surrogate_key(['r.organization_id']) }} as organization_key,
        {{ synthea_date_key('r.discharge_date') }} as discharge_date_key,
        {{ synthea_date_key('r.readmit_date') }} as readmit_date_key,
        r.days_to_readmission,
        r.is_7_day_readmission,
        r.is_30_day_readmission,
        r.is_90_day_readmission,
        r.has_readmission,
        r.is_same_organization_readmission,
        row_number() over (
            partition by r.index_encounter_id
            order by pip.effective_from desc, pip.scd2_version desc
        ) as period_match_rank
    from {{ ref('int_synthea__readmission_flags') }} as r
    left join {{ ref('int_synthea__patient_insurance_periods') }} as pip
        on r.patient_id = pip.patient_id
        and r.discharge_date::date between pip.effective_from and pip.effective_to
    where r.index_encounter_id is not null

)

select
    readmission_key,
    index_encounter_id,
    readmit_encounter_id,
    patient_key,
    organization_key,
    discharge_date_key,
    readmit_date_key,
    days_to_readmission,
    is_7_day_readmission,
    is_30_day_readmission,
    is_90_day_readmission,
    has_readmission,
    is_same_organization_readmission,
    {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_loaded_at
from readmission_base
where period_match_rank = 1
