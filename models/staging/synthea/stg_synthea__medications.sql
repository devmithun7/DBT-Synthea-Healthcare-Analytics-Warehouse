with source as (

    select * from {{ source('synthea', 'medications') }}

),

renamed as (

    select
        {{ synthea_parse_timestamp('START') }} as started_at,
        {{ synthea_parse_timestamp('STOP') }} as stopped_at,
        patient_id,
        payer_id,
        encounter_id,
        code as medication_code,
        description as medication_description,
        base_cost as medication_base_cost,
        dispenses as medication_dispense_count,
        total_cost as medication_total_cost,
        {{ synthea_reason_code() }} as medication_reason_code,
        {{ synthea_reason_description() }} as medication_reason_description,
        payer_coverage as medication_payer_coverage,
        {{ synthea_loaded_at() }} as loaded_at

    from source

)

select * from renamed
