with source as (

    select * from {{ source('synthea', 'payer_transitions') }}

),

renamed as (

    select
        patient as patient_id,
        start_year as coverage_start_year,
        end_year as coverage_end_year,
        payer as payer_id,
        {{ synthea_title_case('ownership') }} as coverage_ownership_type,
        {{ synthea_loaded_at() }} as loaded_at

    from source

)

select * from renamed
