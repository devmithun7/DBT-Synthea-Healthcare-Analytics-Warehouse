{#
  Surrogate keys for marts dimensions and facts (Snowflake md5).
#}

{% macro synthea_surrogate_key(fields) %}
    md5(
        {%- for field in fields -%}
            coalesce({{ field }}::varchar, '')
            {%- if not loop.last %} || '|' || {% endif -%}
        {%- endfor -%}
    )
{% endmacro %}


{% macro synthea_date_key(date_column) %}
    to_number(to_char({{ date_column }}, 'YYYYMMDD'))
{% endmacro %}
