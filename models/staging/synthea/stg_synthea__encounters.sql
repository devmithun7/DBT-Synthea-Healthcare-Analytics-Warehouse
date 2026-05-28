with source as (

    select * from {{ source('synthea', 'encounters') }}

),

renamed as (

    select
        {{ synthea_rename_id('id', 'encounter_id') }},
        {{ synthea_parse_timestamp('START') }} as started_at,
        {{ synthea_parse_timestamp('STOP') }} as ended_at,
        patient_id,
        provider_id,
        organization_id,
        payer_id,
        encounterclass as encounter_class,
        {{ synthea_yes_no_from_boolean("lower(encounterclass) = 'emergency'") }} as is_emergency_visit,
        {{ synthea_yes_no_from_boolean("lower(encounterclass) = 'inpatient'") }} as is_inpatient_visit,
        code as encounter_code,
        description as encounter_description,
        base_encounter_cost,
        total_claim_cost,
        payer_coverage as encounter_payer_coverage,
        {{ synthea_reason_code() }} as encounter_reason_code,
        {{ synthea_reason_description() }} as encounter_reason_description,
        {{ synthea_loaded_at() }} as loaded_at

    from source

)

select * from renamed
