{% macro synthea_test_model_layer(resource_path, model_name=none) %}
    {%- set path = resource_path | lower | replace('\\', '/') -%}
    {%- if 'tests/staging/' in path -%}
        staging
    {%- elif 'tests/intermediate/' in path -%}
        intermediate
    {%- elif 'tests/marts/' in path -%}
        marts
    {%- elif 'tests/reporting/' in path -%}
        reporting
    {%- elif 'models/staging/' in path -%}
        staging
    {%- elif 'models/intermediate/' in path -%}
        intermediate
    {%- elif 'models/marts/' in path -%}
        marts
    {%- elif 'models/reporting/' in path -%}
        reporting
    {%- elif model_name is not none and model_name.startswith('stg_synthea__') -%}
        staging
    {%- elif model_name is not none and model_name.startswith('int_synthea__') -%}
        intermediate
    {%- elif model_name is not none and model_name.startswith('rpt_synthea__') -%}
        reporting
    {%- elif model_name is not none and (
        model_name.startswith('dim_synthea__') or model_name.startswith('fct_synthea__')
    ) -%}
        marts
    {%- else -%}
        other
    {%- endif -%}
{% endmacro %}
