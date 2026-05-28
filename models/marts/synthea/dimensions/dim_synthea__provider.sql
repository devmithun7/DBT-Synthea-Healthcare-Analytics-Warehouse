{{
    config(
        tags=['daily']
    )
}}

select
    {{ synthea_surrogate_key(['provider_id']) }} as provider_key,
    provider_id,
    provider_name,
    provider_gender,
    provider_specialty,
    address_line_1,
    address_city,
    address_state,
    address_postal_code,
    organization_id,
    provider_utilization,
    {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_loaded_at
from {{ ref('stg_synthea__providers') }}
where provider_id is not null
