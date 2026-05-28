{{
    config(
        tags=['daily']
    )
}}

with index_encounters as (

    select
        encounter_id,
        encounter_key,
        payer_key
    from {{ ref('fct_synthea__encounters') }}

),

primary_diagnosis as (

    select
        ie.encounter_id as index_encounter_id,
        ce.clinical_description as primary_diagnosis,
        row_number() over (
            partition by ie.encounter_id
            order by ce.event_start_date desc, ce.clinical_code
        ) as diagnosis_rank
    from index_encounters as ie
    inner join {{ ref('fct_synthea__clinical_events') }} as ce
        on ie.encounter_key = ce.encounter_key
        and ce.event_type = 'condition'
    qualify diagnosis_rank = 1

),

readmissions_enriched as (

    select
        fr.index_encounter_id,
        fr.discharge_date_key,
        fr.is_30_day_readmission,
        coalesce(pd.primary_diagnosis, 'Unknown') as primary_diagnosis,
        coalesce(dpy.payer_name, 'Unknown') as payer_name
    from {{ ref('fct_synthea__readmissions') }} as fr
    left join primary_diagnosis as pd
        on fr.index_encounter_id = pd.index_encounter_id
    left join index_encounters as ie
        on fr.index_encounter_id = ie.encounter_id
    left join {{ ref('dim_synthea__payer') }} as dpy
        on ie.payer_key = dpy.payer_key

),

aggregated as (

    select
        dd.year_month,
        dd.year_num,
        dd.month_num,
        dd.month_name,
        re.primary_diagnosis,
        re.payer_name,
        count(distinct re.index_encounter_id) as discharge_count,
        sum(case when re.is_30_day_readmission = 'Yes' then 1 else 0 end) as readmission_30day_count,
        round(
            100.0 * sum(case when re.is_30_day_readmission = 'Yes' then 1 else 0 end)
            / nullif(count(distinct re.index_encounter_id), 0),
            2
        ) as readmission_30day_rate_pct
    from readmissions_enriched as re
    left join {{ ref('dim_synthea__date') }} as dd
        on re.discharge_date_key = dd.date_key
    group by
        dd.year_month,
        dd.year_num,
        dd.month_num,
        dd.month_name,
        re.primary_diagnosis,
        re.payer_name

)

select
    year_month,
    year_num,
    month_num,
    month_name,
    primary_diagnosis,
    payer_name,
    discharge_count,
    readmission_30day_count,
    readmission_30day_rate_pct,
    case
        when readmission_30day_rate_pct > 15 then 'Alert'
        else 'OK'
    end as quality_flag,
    {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_refreshed_at
from aggregated
