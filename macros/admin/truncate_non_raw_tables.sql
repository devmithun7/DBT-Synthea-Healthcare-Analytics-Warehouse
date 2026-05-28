{% macro truncate_non_raw_tables(target_database=var('raw_database', target.database), raw_schema='RAW') %}
  {% set tables_sql %}
    select table_schema, table_name
    from {{ target_database }}.information_schema.tables
    where table_catalog = '{{ target_database }}'
      and table_schema <> '{{ raw_schema }}'
      and table_type = 'BASE TABLE'
    order by table_schema, table_name
  {% endset %}

  {% set table_results = run_query(tables_sql) %}

  {% if execute and table_results is not none and table_results.rows | length > 0 %}
    {% for row in table_results.rows %}
      {% set schema_name = row[0] %}
      {% set table_name = row[1] %}
      {% set truncate_sql %}
        truncate table {{ adapter.quote(target_database) }}.{{ adapter.quote(schema_name) }}.{{ adapter.quote(table_name) }}
      {% endset %}
      {% do run_query(truncate_sql) %}
      {% do log("Truncated " ~ target_database ~ "." ~ schema_name ~ "." ~ table_name, info=true) %}
    {% endfor %}
  {% else %}
    {% do log("No non-RAW base tables found to truncate in " ~ target_database, info=true) %}
  {% endif %}
{% endmacro %}
