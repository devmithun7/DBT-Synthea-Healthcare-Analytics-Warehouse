{{
    config(
        tags=['daily']
    )
}}

with conditions as (

    select
        {{ synthea_surrogate_key([
            'patient_id',
            'encounter_id',
            "'condition'",
            'condition_code',
            'started_at'
        ]) }} as clinical_event_key,
        patient_id,
        encounter_id,
        'condition' as event_type,
        condition_code as clinical_code,
        condition_description as clinical_description,
        started_at::date as event_start_date,
        stopped_at::date as event_end_date,
        cast(null as float) as event_cost,
        cast(null as number) as dispense_count,
        datediff(
            day,
            started_at::date,
            coalesce(stopped_at::date, current_date())
        ) as duration_days,
        {{ synthea_yes_no_from_boolean('stopped_at is null') }} as is_chronic_condition
    from {{ ref('stg_synthea__conditions') }}

),

procedures as (

    select
        {{ synthea_surrogate_key([
            'patient_id',
            'encounter_id',
            "'procedure'",
            'procedure_code',
            'procedure_at'
        ]) }} as clinical_event_key,
        patient_id,
        encounter_id,
        'procedure' as event_type,
        procedure_code as clinical_code,
        procedure_description as clinical_description,
        procedure_at::date as event_start_date,
        cast(null as date) as event_end_date,
        procedure_base_cost as event_cost,
        cast(null as number) as dispense_count,
        cast(null as number) as duration_days,
        cast(null as varchar) as is_chronic_condition
    from {{ ref('stg_synthea__procedures') }}

),

medications as (

    select
        {{ synthea_surrogate_key([
            'patient_id',
            'encounter_id',
            "'medication'",
            'medication_code',
            'started_at'
        ]) }} as clinical_event_key,
        patient_id,
        encounter_id,
        'medication' as event_type,
        medication_code as clinical_code,
        medication_description as clinical_description,
        started_at::date as event_start_date,
        stopped_at::date as event_end_date,
        medication_total_cost as event_cost,
        medication_dispense_count as dispense_count,
        datediff(
            day,
            started_at::date,
            coalesce(stopped_at::date, current_date())
        ) as duration_days,
        cast(null as varchar) as is_chronic_condition
    from {{ ref('stg_synthea__medications') }}

),

unioned as (

    select * from conditions
    union all
    select * from procedures
    union all
    select * from medications

),

enriched as (

    select
        u.clinical_event_key,
        {{ synthea_surrogate_key(['pip.patient_id', 'pip.effective_from']) }} as patient_key,
        {{ synthea_surrogate_key(['u.encounter_id']) }} as encounter_key,
        {{ synthea_date_key('u.event_start_date') }} as event_date_key,
        u.event_type,
        u.clinical_code,
        u.clinical_description,
        u.event_start_date,
        u.event_end_date,
        u.event_cost,
        u.dispense_count,
        u.duration_days,
        u.is_chronic_condition,
        row_number() over (
            partition by u.clinical_event_key
            order by pip.effective_from desc, pip.scd2_version desc
        ) as period_match_rank
    from unioned as u
    left join {{ ref('int_synthea__patient_insurance_periods') }} as pip
        on u.patient_id = pip.patient_id
        and u.event_start_date between pip.effective_from and pip.effective_to

),

final as (

    select
        clinical_event_key,
        patient_key,
        encounter_key,
        event_date_key,
        event_type,
        clinical_code,
        clinical_description,
        event_start_date,
        event_end_date,
        event_cost,
        dispense_count,
        duration_days,
        is_chronic_condition,
        {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_loaded_at
    from enriched
    where period_match_rank = 1

)

select * from final
