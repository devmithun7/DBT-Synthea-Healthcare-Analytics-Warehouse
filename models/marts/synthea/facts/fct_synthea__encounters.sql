{{
    config(
        tags=['daily']
    )
}}

with encounter_base as (

    select
        {{ synthea_surrogate_key(['e.encounter_id']) }} as encounter_key,
        e.encounter_id,
        {{ synthea_surrogate_key(['pip.patient_id', 'pip.effective_from']) }} as patient_key,
        {{ synthea_surrogate_key(['e.provider_id']) }} as provider_key,
        {{ synthea_surrogate_key(['e.organization_id']) }} as organization_key,
        {{ synthea_surrogate_key(['e.payer_id']) }} as payer_key,
        {{ synthea_date_key('e.encounter_start_time') }} as encounter_date_key,
        e.encounter_start_time,
        e.encounter_stop_time,
        e.care_setting,
        /* enforce non-negative costs and reasonable duration at the mart layer */
        greatest(e.total_claim_cost, 0) as total_claim_cost,
        greatest(e.encounter_payer_coverage, 0) as encounter_payer_coverage,
        greatest(e.patient_out_of_pocket, 0) as patient_out_of_pocket,
        greatest(e.base_encounter_cost, 0) as base_encounter_cost,
        case
            when e.duration_hours < 0 then 0
            when e.duration_hours > 1000 then null
            else e.duration_hours
        end as duration_hours,
        e.is_emergency_visit,
        e.is_inpatient,
        e.encounter_reason_code,
        e.encounter_reason_description,
        row_number() over (
            partition by e.encounter_id
            order by pip.effective_from desc, pip.scd2_version desc
        ) as period_match_rank
    from {{ ref('int_synthea__encounter_enriched') }} as e
    left join {{ ref('int_synthea__patient_insurance_periods') }} as pip
        on e.patient_id = pip.patient_id
        and e.encounter_start_time::date between pip.effective_from and pip.effective_to
    where e.encounter_id is not null

)

select
    encounter_key,
    encounter_id,
    patient_key,
    provider_key,
    organization_key,
    payer_key,
    encounter_date_key,
    encounter_start_time,
    encounter_stop_time,
    care_setting,
    total_claim_cost,
    encounter_payer_coverage,
    patient_out_of_pocket,
    base_encounter_cost,
    duration_hours,
    is_emergency_visit,
    is_inpatient,
    encounter_reason_code,
    encounter_reason_description,
    {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_loaded_at
from encounter_base
where period_match_rank = 1
