{% macro log_test_results(results) %}
    {% if not execute or results is none %}
        {{ return('') }}
    {% endif %}

    {% set audit_db = target.database %}
    {% set audit_schema = var('test_audit_schema', 'REPORTING') %}
    {% set audit_table = var('test_audit_table', 'DBT_TEST_RESULTS') %}
    {% set relation = audit_db ~ '.' ~ audit_schema ~ '.' ~ audit_table %}

    {% do run_query("create schema if not exists " ~ audit_db ~ "." ~ audit_schema) %}
    {% do run_query(
        "create table if not exists " ~ relation ~ " (" ~
        "invocation_id varchar, " ~
        "run_started_at timestamp_ntz, " ~
        "generated_at timestamp_ntz, " ~
        "target_name varchar, " ~
        "database_name varchar, " ~
        "schema_name varchar, " ~
        "test_unique_id varchar, " ~
        "test_name varchar, " ~
        "resource_name varchar, " ~
        "resource_path varchar, " ~
        "status varchar, " ~
        "failures number, " ~
        "execution_time_seconds float, " ~
        "message varchar, " ~
        "target_model_unique_id varchar, " ~
        "target_model_name varchar, " ~
        "target_model_resource_type varchar, " ~
        "target_model_schema varchar, " ~
        "model_layer varchar, " ~
        "profile_default_schema varchar, " ~
        "depends_on_nodes varchar, " ~
        "logged_at timestamp_ntz default current_timestamp()" ~
        ")"
    ) %}

    {% do run_query(
        "alter table if exists " ~ relation ~ " add column if not exists target_model_schema varchar"
    ) %}
    {% do run_query(
        "alter table if exists " ~ relation ~ " add column if not exists model_layer varchar"
    ) %}
    {% do run_query(
        "alter table if exists " ~ relation ~ " add column if not exists profile_default_schema varchar"
    ) %}

    {% for result in results %}
        {% if result.node.resource_type == 'test' %}
            {% set test_unique_id = result.node.unique_id | replace("'", "''") %}
            {% set test_name = result.node.name | replace("'", "''") %}
            {% set resource_name = (result.node.name | replace("'", "''")) %}
            {% set resource_path = result.node.original_file_path | replace("'", "''") %}
            {% set status = result.status | replace("'", "''") %}
            {% set failures = result.failures if result.failures is not none else 'null' %}
            {% set execution_time = result.execution_time if result.execution_time is not none else 0 %}
            {% set message = (result.message if result.message is not none else '') | replace("'", "''") %}
            {% set generated_at_value = run_started_at %}

            {# derive target model info from depends_on nodes #}
            {% set depends_on_ids = result.node.depends_on.nodes if result.node.depends_on is defined else [] %}
            {% set depends_on_str = depends_on_ids | join(',') | replace("'", "''") %}
            {% set target_model_unique_id = (depends_on_ids[0] if depends_on_ids | length > 0 else none) %}
            {% if target_model_unique_id is not none and graph is defined and target_model_unique_id in graph.nodes %}
                {% set target_node = graph.nodes[target_model_unique_id] %}
                {% set target_model_name = target_node.name | replace("'", "''") %}
                {% set target_model_resource_type = target_node.resource_type | replace("'", "''") %}
                {% set target_model_schema = target_node.schema | replace("'", "''") %}
                {% set model_layer = synthea_test_model_layer(
                    result.node.original_file_path,
                    target_node.name
                ) | replace("'", "''") %}
            {% else %}
                {% set target_model_name = '' %}
                {% set target_model_resource_type = '' %}
                {% set target_model_schema = '' %}
                {% set model_layer = synthea_test_model_layer(
                    result.node.original_file_path
                ) | replace("'", "''") %}
            {% endif %}
            {% set target_model_unique_id_clean = (target_model_unique_id if target_model_unique_id is not none else '') | replace("'", "''") %}
            {% set profile_default_schema = target.schema | replace("'", "''") %}
            {# schema_name: model schema under test (not profile default STAGING) #}
            {% set schema_name = target_model_schema if target_model_schema != '' else profile_default_schema %}

            {% set insert_sql %}
                insert into {{ relation }} (
                    invocation_id,
                    run_started_at,
                    generated_at,
                    target_name,
                    database_name,
                    schema_name,
                    test_unique_id,
                    test_name,
                    resource_name,
                    resource_path,
                    status,
                    failures,
                    execution_time_seconds,
                    message,
                    target_model_unique_id,
                    target_model_name,
                    target_model_resource_type,
                    target_model_schema,
                    model_layer,
                    profile_default_schema,
                    depends_on_nodes
                )
                values (
                    '{{ invocation_id }}',
                    '{{ run_started_at }}'::timestamp_ntz,
                    '{{ generated_at_value }}'::timestamp_ntz,
                    '{{ target.name }}',
                    '{{ target.database }}',
                    '{{ schema_name }}',
                    '{{ test_unique_id }}',
                    '{{ test_name }}',
                    '{{ resource_name }}',
                    '{{ resource_path }}',
                    '{{ status }}',
                    {{ failures }},
                    {{ execution_time }},
                    '{{ message }}',
                    '{{ target_model_unique_id_clean }}',
                    '{{ target_model_name }}',
                    '{{ target_model_resource_type }}',
                    '{{ target_model_schema }}',
                    '{{ model_layer }}',
                    '{{ profile_default_schema }}',
                    '{{ depends_on_str }}'
                )
            {% endset %}
            {% do run_query(insert_sql) %}
        {% endif %}
    {% endfor %}

{% endmacro %}
