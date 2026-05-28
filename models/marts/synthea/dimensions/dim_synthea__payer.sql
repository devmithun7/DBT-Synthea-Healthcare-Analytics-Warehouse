{{
    config(
        tags=['daily']
    )
}}

select
    {{ synthea_surrogate_key(['payer_id']) }} as payer_key,
    payer_id,
    payer_name,
    headquarters_address_line_1 as address_line_1,
    headquarters_address_city as address_city,
    headquarters_address_state as address_state,
    headquarters_address_postal_code as address_postal_code,
    payer_phone_number,
    payer_revenue,
    {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_loaded_at
from {{ ref('stg_synthea__payers') }}
where payer_id is not null
