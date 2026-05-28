{{
    config(
        tags=['daily']
    )
}}

/*
  Inpatient discharge readmission flags (first subsequent encounter per discharge).
  Grain: one row per inpatient discharge encounter.
*/

with encounters as (

    select
        encounter_id,
        patient_id,
        encounter_class,
        started_at,
        ended_at,
        organization_id
    from {{ ref('stg_synthea__encounters') }}

),

inpatient_discharges as (

    select
        encounter_id as index_encounter_id,
        patient_id,
        ended_at as discharge_date,
        organization_id as index_organization_id
    from encounters
    where lower(encounter_class) = 'inpatient'
        and ended_at is not null

),

first_readmission as (

    select
        d.index_encounter_id,
        e.encounter_id as readmit_encounter_id,
        d.patient_id,
        d.index_organization_id,
        d.discharge_date,
        e.started_at as readmit_date,
        e.organization_id as readmit_organization_id,
        datediff('day', d.discharge_date, e.started_at) as days_to_readmission,
        row_number() over (
            partition by d.index_encounter_id
            order by e.started_at, e.encounter_id
        ) as readmit_rank
    from inpatient_discharges as d
    inner join encounters as e
        on d.patient_id = e.patient_id
        and e.started_at > d.discharge_date

),

readmission_flags as (

    select
        d.index_encounter_id,
        r.readmit_encounter_id,
        d.patient_id,
        d.index_organization_id as organization_id,
        d.discharge_date,
        r.readmit_date,
        r.readmit_organization_id,
        r.days_to_readmission,
        {{ synthea_yes_no_from_boolean('r.readmit_encounter_id is not null') }} as has_readmission,
        {{ synthea_yes_no_from_boolean(
            'r.days_to_readmission is not null and r.days_to_readmission <= 7'
        ) }} as is_7_day_readmission,
        {{ synthea_yes_no_from_boolean(
            'r.days_to_readmission is not null and r.days_to_readmission <= 30'
        ) }} as is_30_day_readmission,
        {{ synthea_yes_no_from_boolean(
            'r.days_to_readmission is not null and r.days_to_readmission <= 90'
        ) }} as is_90_day_readmission,
        {{ synthea_yes_no_from_boolean(
            'r.readmit_encounter_id is not null and r.readmit_organization_id = d.index_organization_id'
        ) }} as is_same_organization_readmission
    from inpatient_discharges as d
    left join first_readmission as r
        on d.index_encounter_id = r.index_encounter_id
        and r.readmit_rank = 1

)

select * from readmission_flags
