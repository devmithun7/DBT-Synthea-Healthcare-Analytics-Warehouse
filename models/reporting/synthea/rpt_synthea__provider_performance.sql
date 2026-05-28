{{
    config(
        tags=['daily']
    )
}}

with provider_encounters as (

    select
        dpr.provider_key,
        dpr.provider_id,
        dpr.provider_name,
        dpr.provider_specialty,
        dorg.organization_name,
        dorg.address_city,
        dorg.address_state,
        fe.encounter_id,
        fe.patient_key,
        fe.total_claim_cost,
        fe.encounter_payer_coverage,
        fe.is_emergency_visit,
        fe.is_inpatient
    from {{ ref('fct_synthea__encounters') }} as fe
    inner join {{ ref('dim_synthea__provider') }} as dpr
        on fe.provider_key = dpr.provider_key
    left join {{ ref('dim_synthea__organization') }} as dorg
        on dpr.organization_id = dorg.organization_id

),

provider_readmissions as (

    select
        pe.provider_key,
        fr.index_encounter_id,
        fr.is_30_day_readmission
    from provider_encounters as pe
    inner join {{ ref('fct_synthea__readmissions') }} as fr
        on pe.encounter_id = fr.index_encounter_id

),

aggregated as (

    select
        pe.provider_key,
        pe.provider_id,
        pe.provider_name,
        pe.provider_specialty,
        pe.organization_name,
        pe.address_city,
        pe.address_state,
        count(distinct pe.encounter_id) as total_encounters,
        count(distinct pe.patient_key) as unique_patients,
        sum(case when pe.is_emergency_visit = 'Yes' then 1 else 0 end) as emergency_encounters,
        sum(case when pe.is_inpatient = 'Yes' then 1 else 0 end) as inpatient_encounters,
        sum(pe.total_claim_cost) as total_cost,
        round(avg(pe.total_claim_cost), 2) as avg_cost_per_encounter,
        round(
            sum(pe.total_claim_cost) / nullif(count(distinct pe.encounter_id), 0),
            2
        ) as cost_per_visit,
        sum(pe.encounter_payer_coverage) as total_payer_coverage,
        count(distinct pr.index_encounter_id) as inpatient_discharges,
        sum(case when pr.is_30_day_readmission = 'Yes' then 1 else 0 end) as readmission_30day_count,
        round(
            100.0 * sum(case when pr.is_30_day_readmission = 'Yes' then 1 else 0 end)
            / nullif(count(distinct pr.index_encounter_id), 0),
            2
        ) as readmission_30day_rate_pct
    from provider_encounters as pe
    left join provider_readmissions as pr
        on pe.encounter_id = pr.index_encounter_id
    group by
        pe.provider_key,
        pe.provider_id,
        pe.provider_name,
        pe.provider_specialty,
        pe.organization_name,
        pe.address_city,
        pe.address_state

)

select
    provider_key,
    provider_id,
    provider_name,
    provider_specialty,
    organization_name,
    address_city,
    address_state,
    total_encounters,
    unique_patients,
    emergency_encounters,
    inpatient_encounters,
    total_cost,
    avg_cost_per_encounter,
    cost_per_visit,
    total_payer_coverage,
    inpatient_discharges,
    readmission_30day_count,
    readmission_30day_rate_pct,
    case
        when readmission_30day_rate_pct > 20 then 'High Risk (Readmission)'
        when avg_cost_per_encounter > 10000 then 'High Cost'
        when total_encounters < 10 then 'Low Volume'
        else 'OK'
    end as quality_flag,
    {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_refreshed_at
from aggregated
where total_encounters >= 1
