{{
    config(
        tags=['daily']
    )
}}

/*
  Encounter enrichment with provider, organization, and payer context.
  Grain: one row per encounter.
*/

select
    e.encounter_id,
    e.patient_id,
    e.started_at as encounter_start_time,
    e.ended_at as encounter_stop_time,
    datediff('hour', e.started_at, e.ended_at) as duration_hours,
    case
        when lower(e.encounter_class) = 'wellness' then 'wellness'
        when lower(e.encounter_class) = 'ambulatory' then 'ambulatory'
        when lower(e.encounter_class) = 'emergency' then 'emergency'
        when lower(e.encounter_class) = 'urgentcare' then 'urgent_care'
        when lower(e.encounter_class) = 'inpatient' then 'inpatient'
        else 'other'
    end as care_setting,
    e.base_encounter_cost,
    e.total_claim_cost,
    e.encounter_payer_coverage,
    coalesce(e.total_claim_cost, 0) - coalesce(e.encounter_payer_coverage, 0) as patient_out_of_pocket,
    round(
        100.0 * e.encounter_payer_coverage / nullif(e.total_claim_cost, 0),
        2
    ) as payer_coverage_pct,
    e.is_emergency_visit,
    e.is_inpatient_visit as is_inpatient,
    pr.provider_id,
    pr.provider_name,
    pr.provider_specialty,
    o.organization_id,
    o.organization_name,
    o.address_city as organization_city,
    o.address_state as organization_state,
    py.payer_id,
    py.payer_name,
    e.encounter_reason_code,
    e.encounter_reason_description
from {{ ref('stg_synthea__encounters') }} as e
left join {{ ref('stg_synthea__providers') }} as pr
    on e.provider_id = pr.provider_id
left join {{ ref('stg_synthea__organizations') }} as o
    on e.organization_id = o.organization_id
left join {{ ref('stg_synthea__payers') }} as py
    on e.payer_id = py.payer_id
