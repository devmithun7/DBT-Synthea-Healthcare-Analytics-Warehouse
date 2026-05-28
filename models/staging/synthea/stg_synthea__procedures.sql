with source as (

    select * from {{ source('synthea', 'procedures') }}

),

renamed as (

    select
        {{ synthea_parse_timestamp('DATE') }} as procedure_at,
        patient as patient_id,
        encounter as encounter_id,
        code as procedure_code,
        description as procedure_description,
        base_cost as procedure_base_cost,
        {{ synthea_reason_code() }} as procedure_reason_code,
        {{ synthea_reason_description() }} as procedure_reason_description,
        {{ synthea_loaded_at() }} as loaded_at

    from source

)

select * from renamed
