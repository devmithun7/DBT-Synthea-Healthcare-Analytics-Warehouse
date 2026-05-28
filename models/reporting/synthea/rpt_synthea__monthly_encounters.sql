{{
    config(
        tags=['daily']
    )
}}

select
    dd.year_month,
    dd.year_num,
    dd.month_num,
    dd.month_name,
    fe.care_setting,
    coalesce(dpy.payer_name, 'Unknown') as payer_name,
    count(distinct fe.encounter_id) as encounter_count,
    sum(case when fe.is_emergency_visit = 'Yes' then 1 else 0 end) as emergency_count,
    sum(case when fe.is_inpatient = 'Yes' then 1 else 0 end) as inpatient_count,
    sum(fe.total_claim_cost) as total_encounter_cost,
    round(avg(fe.total_claim_cost), 2) as avg_encounter_cost,
    sum(fe.encounter_payer_coverage) as total_payer_coverage,
    sum(fe.patient_out_of_pocket) as total_patient_oop,
    round(avg(fe.duration_hours), 2) as avg_duration_hours,
    max(fe.duration_hours) as max_duration_hours,
    round(
        100.0 * sum(fe.encounter_payer_coverage) / nullif(sum(fe.total_claim_cost), 0),
        2
    ) as payer_coverage_pct,
    {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_refreshed_at
from {{ ref('fct_synthea__encounters') }} as fe
left join {{ ref('dim_synthea__payer') }} as dpy
    on fe.payer_key = dpy.payer_key
left join {{ ref('dim_synthea__date') }} as dd
    on fe.encounter_date_key = dd.date_key
group by
    dd.year_month,
    dd.year_num,
    dd.month_num,
    dd.month_name,
    fe.care_setting,
    coalesce(dpy.payer_name, 'Unknown')
