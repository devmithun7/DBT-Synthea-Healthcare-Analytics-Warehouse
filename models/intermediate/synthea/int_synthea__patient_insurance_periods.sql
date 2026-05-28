{{
    config(
        tags=['daily']
    )
}}

/*
  Patient insurance periods (SCD2 prep).
  Grain: one row per patient per payer coverage period.
*/

with patient_base as (

    select
        patient_id,
        first_name,
        last_name,
        patient_gender,
        race,
        ethnicity,
        birth_date as date_of_birth
    from {{ ref('stg_synthea__patients') }}

),

insurance_periods as (

    select
        pb.patient_id,
        pb.first_name,
        pb.last_name,
        pb.patient_gender,
        pb.race,
        pb.ethnicity,
        pb.date_of_birth,
        pt.payer_id,
        py.payer_name,
        date_from_parts(pt.coverage_start_year, 1, 1) as effective_from,
        date_from_parts(
            coalesce(pt.coverage_end_year, year(current_date())),
            12,
            31
        ) as effective_to,
        {{ synthea_yes_no_from_boolean(
            "coalesce(pt.coverage_end_year, 9999) >= year(current_date())"
        ) }} as is_current,
        row_number() over (
            partition by pb.patient_id
            order by pt.coverage_start_year, pt.payer_id
        ) as scd2_version
    from patient_base as pb
    inner join {{ ref('stg_synthea__payer_transitions') }} as pt
        on pb.patient_id = pt.patient_id
    left join {{ ref('stg_synthea__payers') }} as py
        on pt.payer_id = py.payer_id

)

select * from insurance_periods
