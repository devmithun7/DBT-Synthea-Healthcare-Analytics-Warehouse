with source as (

    select * from {{ source('synthea', 'payers') }}

),

renamed as (

    select
        {{ synthea_rename_id('id', 'payer_id') }},
        {{ synthea_entity_name('name', 'payer_name') }},
        {{ synthea_address_line_1('address', 'headquarters_address_line_1') }},
        {{ synthea_address_city('city', 'headquarters_address_city') }},
        {{ synthea_state_code('state_headquartered', 'headquarters_address_state') }},
        {{ synthea_zip_code('zip', 'headquarters_address_postal_code') }},
        {{ synthea_phone_number('phone', 'payer_phone_number') }},
        amount_covered,
        amount_uncovered,
        revenue as payer_revenue,
        covered_encounters,
        uncovered_encounters,
        covered_medications,
        uncovered_medications,
        covered_procedures,
        uncovered_procedures,
        covered_immunizations,
        uncovered_immunizations,
        unique_customers,
        qols_avg,
        member_months,
        {{ synthea_loaded_at() }} as loaded_at

    from source

)

select * from renamed
