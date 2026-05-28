with source as (

    select * from {{ source('synthea', 'conditions') }}

),

renamed as (

    select
        {{ synthea_parse_timestamp('START') }} as started_at,
        {{ synthea_parse_timestamp('STOP') }} as stopped_at,
        patient_id,
        encounter_id,
        code as condition_code,
        description as condition_description,
        {{ synthea_loaded_at() }} as loaded_at

    from source

)

select * from renamed
