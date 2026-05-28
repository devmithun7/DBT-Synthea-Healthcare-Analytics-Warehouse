{{
    config(
        tags=['daily']
    )
}}

select
    {{ synthea_surrogate_key(['organization_id']) }} as organization_key,
    organization_id,
    organization_name,
    address_line_1,
    address_city,
    address_state,
    address_postal_code,
    organization_phone_number,
    organization_revenue,
    organization_utilization,
    {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_loaded_at
from {{ ref('stg_synthea__organizations') }}
where organization_id is not null
