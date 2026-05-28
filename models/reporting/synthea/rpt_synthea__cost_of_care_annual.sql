{{
    config(
        tags=['daily']
    )
}}

with encounter_patient as (

    select
        fe.encounter_id,
        fe.total_claim_cost,
        fe.encounter_payer_coverage,
        fe.patient_out_of_pocket,
        fe.is_emergency_visit,
        fe.is_inpatient,
        dd.fiscal_year,
        dp.patient_id,
        dp.first_name,
        dp.last_name,
        dp.patient_gender,
        dp.race
    from {{ ref('fct_synthea__encounters') }} as fe
    inner join {{ ref('dim_synthea__patient') }} as dp
        on fe.patient_key = dp.patient_key
    left join {{ ref('dim_synthea__date') }} as dd
        on fe.encounter_date_key = dd.date_key

),

aggregated as (

    select
        patient_id,
        max(first_name) as first_name,
        max(last_name) as last_name,
        max(patient_gender) as patient_gender,
        max(race) as race,
        fiscal_year,
        count(distinct encounter_id) as encounter_count,
        sum(case when is_emergency_visit = 'Yes' then 1 else 0 end) as emergency_visit_count,
        sum(case when is_inpatient = 'Yes' then 1 else 0 end) as inpatient_admission_count,
        sum(total_claim_cost) as total_encounter_cost,
        round(avg(total_claim_cost), 2) as avg_cost_per_encounter,
        sum(encounter_payer_coverage) as total_payer_coverage,
        sum(patient_out_of_pocket) as total_patient_oop
    from encounter_patient
    where fiscal_year is not null
    group by
        patient_id,
        fiscal_year

)

select
    {{ synthea_surrogate_key(['patient_id', 'fiscal_year']) }} as cost_of_care_key,
    patient_id,
    first_name || ' ' || last_name as patient_name,
    patient_gender,
    race,
    fiscal_year,
    case
        when extract(month from current_date()) >= 10
            then extract(year from current_date()) + 1
        else extract(year from current_date())
    end as current_fiscal_year,
    encounter_count,
    emergency_visit_count,
    inpatient_admission_count,
    total_encounter_cost,
    avg_cost_per_encounter,
    total_payer_coverage,
    total_patient_oop,
    case
        when total_encounter_cost > 100000 then 'High Cost'
        when total_encounter_cost > 50000 then 'Medium Cost'
        else 'Low Cost'
    end as cost_category,
    {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_refreshed_at
from aggregated
where encounter_count > 0
