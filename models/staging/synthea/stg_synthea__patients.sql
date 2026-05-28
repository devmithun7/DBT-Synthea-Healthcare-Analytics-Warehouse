with source as (

    select * from {{ source('synthea', 'patients') }}

),

renamed as (

    select
        {{ synthea_rename_id('id', 'patient_id') }},
        {{ synthea_parse_date('birthdate') }} as birth_date,
        {{ synthea_parse_date('deathdate') }} as death_date,
        {{ synthea_digits_only('ssn') }} as social_security_number,
        {{ synthea_digits_only('drivers') }} as drivers_license_number,
        passport as passport_number,
        {{ synthea_title_case('prefix') }} as name_prefix,
        {{ synthea_title_case('first') }} as first_name,
        {{ synthea_title_case('last') }} as last_name,
        {{ synthea_title_case('suffix') }} as name_suffix,
        {{ synthea_title_case('maiden') }} as maiden_name,
        {{ synthea_title_case('marital') }} as marital_status,
        {{ synthea_title_case('race') }} as race,
        {{ synthea_title_case('ethnicity') }} as ethnicity,
        {{ synthea_upper_trim('gender') }} as patient_gender,
        {{ synthea_title_case('birthplace') }} as birth_place,
        {{ synthea_address_line_1('address', 'home_address_line_1') }},
        {{ synthea_address_city('city', 'home_address_city') }},
        {{ synthea_address_county('county', 'home_address_county') }},
        {{ synthea_state_code('state', 'home_address_state') }},
        {{ synthea_zip_code('zip', 'home_address_postal_code') }},
        {{ synthea_address_latitude('lat', 'home_address_latitude') }},
        {{ synthea_address_longitude('lon', 'home_address_longitude') }},
        healthcare_expenses,
        healthcare_coverage,
        {{ synthea_loaded_at() }} as loaded_at

    from source

)

select * from renamed
