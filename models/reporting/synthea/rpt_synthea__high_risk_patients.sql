{{
    config(
        tags=['daily']
    )
}}

with latest_patients as (

    select
        patient_id,
        first_name,
        last_name,
        patient_gender,
        date_of_birth,
        payer_name
    from {{ ref('dim_synthea__patient') }}
    qualify row_number() over (
        partition by patient_id
        order by effective_from desc, scd2_version desc
    ) = 1

),

patient_encounters as (

    select
        e.patient_id,
        count(distinct e.encounter_id) as total_encounters,
        sum(e.total_claim_cost) as total_cost_ytd,
        sum(case when e.is_emergency_visit = 'Yes' then 1 else 0 end) as ed_visit_count,
        max(
            case when e.is_emergency_visit = 'Yes' then {{ synthea_date_key('e.encounter_start_time') }} end
        ) as last_ed_visit_date
    from {{ ref('int_synthea__encounter_enriched') }} as e
    group by e.patient_id

),

patient_readmissions as (

    select
        fr.patient_id,
        count(distinct fr.index_encounter_id) as readmission_count,
        max(
            case when fr.is_30_day_readmission = 'Yes' then {{ synthea_date_key('fr.discharge_date') }} end
        ) as last_readmission_date
    from {{ ref('int_synthea__readmission_flags') }} as fr
    group by fr.patient_id

),

patient_chronic_conditions as (

    select
        c.patient_id,
        count(distinct c.condition_code) as chronic_condition_count,
        listagg(distinct c.condition_description, ', ') as chronic_conditions_list
    from {{ ref('stg_synthea__conditions') }} as c
    where c.stopped_at is null
    group by c.patient_id

),

scored as (

    select
        cp.patient_id,
        cp.first_name || ' ' || cp.last_name as patient_name,
        cp.patient_gender,
        datediff(year, cp.date_of_birth, current_date()) as age,
        cp.payer_name,
        coalesce(pe.total_encounters, 0) as total_encounters,
        coalesce(pe.ed_visit_count, 0) as ed_visit_count,
        pe.last_ed_visit_date,
        coalesce(pe.total_cost_ytd, 0) as total_cost_ytd,
        round(
            coalesce(pe.total_cost_ytd, 0) / nullif(pe.total_encounters, 0),
            2
        ) as avg_cost_per_encounter,
        coalesce(pr.readmission_count, 0) as readmission_count,
        pr.last_readmission_date,
        coalesce(pcc.chronic_condition_count, 0) as chronic_condition_count,
        pcc.chronic_conditions_list,
        case
            when coalesce(pr.readmission_count, 0) >= 2
                or (
                    coalesce(pr.readmission_count, 0) >= 1
                    and coalesce(pcc.chronic_condition_count, 0) >= 2
                )
                then 'Very High'
            when coalesce(pe.total_cost_ytd, 0) > 100000
                or coalesce(pe.ed_visit_count, 0) >= 4
                or coalesce(pcc.chronic_condition_count, 0) >= 3
                then 'High'
            when coalesce(pcc.chronic_condition_count, 0) >= 2
                then 'Moderate'
            else 'Low'
        end as risk_level
    from latest_patients as cp
    left join patient_encounters as pe
        on cp.patient_id = pe.patient_id
    left join patient_readmissions as pr
        on cp.patient_id = pr.patient_id
    left join patient_chronic_conditions as pcc
        on cp.patient_id = pcc.patient_id

)

select
    {{ synthea_surrogate_key(['patient_id']) }} as patient_key,
    patient_id,
    patient_name,
    patient_gender,
    age,
    payer_name,
    total_encounters,
    ed_visit_count,
    last_ed_visit_date,
    total_cost_ytd,
    avg_cost_per_encounter,
    readmission_count,
    last_readmission_date,
    chronic_condition_count,
    chronic_conditions_list,
    risk_level,
    case
        when readmission_count >= 1 then 'Recent Readmission'
        when ed_visit_count >= 3 then 'Frequent ED User'
        when total_cost_ytd > 100000 then 'High Cost'
        when chronic_condition_count >= 3 then 'Multiple Chronic Conditions'
        else 'Other'
    end as primary_risk_factor,
    {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_refreshed_at
from scored
where risk_level in ('Very High', 'High', 'Moderate')
