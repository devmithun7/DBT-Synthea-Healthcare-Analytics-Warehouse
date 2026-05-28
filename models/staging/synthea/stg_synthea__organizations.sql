with source as (

    select * from {{ source('synthea', 'organizations') }}

),

renamed as (

    select
        {{ synthea_rename_id('id', 'organization_id') }},
        {{ synthea_entity_name('name', 'organization_name') }},
        {{ synthea_address_line_1('address', 'address_line_1') }},
        {{ synthea_address_city('city', 'address_city') }},
        {{ synthea_state_code('state', 'address_state') }},
        {{ synthea_zip_code('zip', 'address_postal_code') }},
        {{ synthea_address_latitude('lat', 'address_latitude') }},
        {{ synthea_address_longitude('lon', 'address_longitude') }},
        {{ synthea_phone_number('phone', 'organization_phone_number') }},
        revenue as organization_revenue,
        utilization as organization_utilization,
        {{ synthea_loaded_at() }} as loaded_at

    from source

)

select * from renamed
