{#
  Standardized column expressions for Synthea RAW → STAGING transforms.
  Use inside SELECT lists: {{ synthea_loaded_at() }} as loaded_at
#}

{# --- audit / defaults --- #}

{% macro synthea_loaded_at(loaded_at_column='_loaded_at') %}
    coalesce({{ loaded_at_column }}, {{ dbt.current_timestamp_backcompat() }})::timestamp_ntz
{% endmacro %}


{% macro synthea_reason_code(reason_code_column='reasoncode', default_value='-9999999') %}
    coalesce({{ reason_code_column }}, '{{ default_value }}')
{% endmacro %}


{% macro synthea_reason_description(
    reason_description_column='reasondescription',
    default_value='not available'
) %}
    coalesce({{ reason_description_column }}, '{{ default_value }}')
{% endmacro %}


{# --- text / names --- #}

{% macro synthea_title_case(column_name) %}
    case
        when {{ column_name }} is null or trim({{ column_name }}) = '' then null
        else initcap(trim({{ column_name }}))
    end
{% endmacro %}


{% macro synthea_upper_trim(column_name) %}
    case
        when {{ column_name }} is null or trim({{ column_name }}) = '' then null
        else upper(trim({{ column_name }}))
    end
{% endmacro %}


{#
  Map binary values to Yes/No labels.
  Accepts 0/1, boolean, or string '0'/'1'.
#}
{% macro synthea_yes_no(column_name) %}
    case
        when {{ column_name }} is null then null
        when {{ column_name }}::varchar in ('1', 'true', 'TRUE', 'Yes', 'yes') then 'Yes'
        when {{ column_name }}::varchar in ('0', 'false', 'FALSE', 'No', 'no') then 'No'
        else null
    end
{% endmacro %}


{% macro synthea_yes_no_from_boolean(boolean_expression) %}
    case
        when {{ boolean_expression }} then 'Yes'
        else 'No'
    end
{% endmacro %}


{# --- dates / timestamps --- #}

{#
  Calendar dates (e.g. birthdate as yyyy-mm-dd text or date).
#}
{% macro synthea_parse_date(column_name) %}
    try_to_date({{ column_name }}::varchar)
{% endmacro %}


{#
  Event timestamps. Reserved words (START, STOP, DATE) must be quoted in Snowflake.
  Handles yyyy-mm-dd and full ISO timestamp strings.
#}
{% macro synthea_parse_timestamp(column_name) %}
    try_to_timestamp("{{ column_name }}")::timestamp_ntz
{% endmacro %}


{# --- identifiers / contact --- #}

{% macro synthea_digits_only(column_name) %}
    nullif(regexp_replace(trim({{ column_name }}), '[^0-9]', ''), '')
{% endmacro %}


{#
  Strip formatting (dashes, spaces, parentheses) and cast to number.
  Returns null when no digits remain.
#}
{% macro synthea_phone_number(phone_column='phone', alias=none) %}
    {% set expression -%}
        try_to_number({{ synthea_digits_only(phone_column) }})
    {%- endset %}
    {%- if alias is not none -%}
        {{ expression }} as {{ alias }}
    {%- else -%}
        {{ expression }}
    {%- endif -%}
{% endmacro %}


{% macro synthea_state_code(column_name='state', alias=none) %}
    {% set expression %}{{ synthea_upper_trim(column_name) }}{% endset %}
    {%- if alias is not none -%}
        {{ expression }} as {{ alias }}
    {%- else -%}
        {{ expression }}
    {%- endif -%}
{% endmacro %}


{% macro synthea_zip_code(column_name='zip', alias=none) %}
    {% set expression %}
        case
            when {{ column_name }} is null or trim({{ column_name }}::varchar) = '' then null
            else lpad(left({{ synthea_digits_only(column_name) }}, 5), 5, '0')
        end
    {% endset %}
    {%- if alias is not none -%}
        {{ expression }} as {{ alias }}
    {%- else -%}
        {{ expression }}
    {%- endif -%}
{% endmacro %}


{# --- aliased renames (entity-prefixed staging columns) --- #}

{% macro synthea_entity_name(column_name='name', alias='entity_name') %}
    {{ synthea_title_case(column_name) }} as {{ alias }}
{% endmacro %}


{% macro synthea_address_line_1(column_name='address', alias='address_line_1') %}
    {{ synthea_title_case(column_name) }} as {{ alias }}
{% endmacro %}


{% macro synthea_address_city(column_name='city', alias='address_city') %}
    {{ synthea_title_case(column_name) }} as {{ alias }}
{% endmacro %}


{% macro synthea_address_county(column_name='county', alias='address_county') %}
    {{ synthea_title_case(column_name) }} as {{ alias }}
{% endmacro %}


{% macro synthea_address_latitude(lat_column='lat', alias='address_latitude') %}
    {{ lat_column }}::float as {{ alias }}
{% endmacro %}


{% macro synthea_address_longitude(lon_column='lon', alias='address_longitude') %}
    {{ lon_column }}::float as {{ alias }}
{% endmacro %}


{# --- geo (legacy aliases; prefer synthea_address_latitude) --- #}

{% macro synthea_latitude(lat_column='lat', alias='latitude') %}
    {{ synthea_address_latitude(lat_column, alias) }}
{% endmacro %}


{% macro synthea_longitude(lon_column='lon', alias='longitude') %}
    {{ synthea_address_longitude(lon_column, alias) }}
{% endmacro %}


{% macro synthea_rename_id(id_column='id', alias='id') %}
    {{ id_column }} as {{ alias }}
{% endmacro %}
