with source as (

    select * from {{ source('synthea', 'providers') }}

),

renamed as (

    select
        {{ synthea_rename_id('id', 'provider_id') }},
        organization as organization_id,
        {{ synthea_entity_name('name', 'provider_name') }},
        {{ synthea_upper_trim('gender') }} as provider_gender,
        {{ synthea_title_case('speciality') }} as provider_specialty,
        {{ synthea_address_line_1('address', 'address_line_1') }},
        {{ synthea_address_city('city', 'address_city') }},
        {{ synthea_state_code('state', 'address_state') }},
        {{ synthea_zip_code('zip', 'address_postal_code') }},
        {{ synthea_address_latitude('lat', 'address_latitude') }},
        {{ synthea_address_longitude('lon', 'address_longitude') }},
        utilization as provider_utilization,
        {{ synthea_loaded_at() }} as loaded_at

    from source

)

select * from renamed
