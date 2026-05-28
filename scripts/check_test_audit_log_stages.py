"""
Summarize DBT_TEST_RESULTS by stage (staging/intermediate/marts/reporting)
for the latest dbt invocation.
"""

import os
import sys

import snowflake.connector


def main() -> None:
    password = os.environ.get("SNOWFLAKE_PASSWORD")
    if not password:
        print("Set SNOWFLAKE_PASSWORD", file=sys.stderr)
        sys.exit(1)

    conn = snowflake.connector.connect(
        account="DCLVOWK-UW14956",
        user="DEVMITH",
        password=password,
        role="ACCOUNTADMIN",
        database="SYNTHEA_WAREHOUSE",
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
        schema="REPORTING",
    )
    cur = conn.cursor()

    cur.execute(
        """
        select invocation_id
        from DBT_TEST_RESULTS
        order by logged_at desc
        limit 1
        """
    )
    invocation_id = cur.fetchone()[0]
    print("latest_invocation_id:", invocation_id)

    cur.execute(
        f"""
        with base as (
            select
                resource_path,
                status,
                model_layer,
                target_model_schema,
                schema_name
            from DBT_TEST_RESULTS
            where invocation_id = '{invocation_id}'
        )
        select
            coalesce(
                nullif(model_layer, ''),
                case
                    when resource_path ilike '%tests/staging%' or resource_path ilike '%tests\\staging\\%' then 'staging'
                    when resource_path ilike '%tests/intermediate%' or resource_path ilike '%tests\\intermediate\\%' then 'intermediate'
                    when resource_path ilike '%tests/marts%' or resource_path ilike '%tests\\marts\\%' then 'marts'
                    when resource_path ilike '%tests/reporting%' or resource_path ilike '%tests\\reporting\\%' then 'reporting'
                    when resource_path ilike '%models/marts%' or resource_path ilike '%models\\marts\\%' then 'marts'
                    when resource_path ilike '%models/reporting%' or resource_path ilike '%models\\reporting\\%' then 'reporting'
                    when resource_path ilike '%models/staging%' or resource_path ilike '%models\\staging\\%' then 'staging'
                    when resource_path ilike '%models/intermediate%' or resource_path ilike '%models\\intermediate\\%' then 'intermediate'
                    else 'other'
                end
            ) as stage,
            status,
            count(*) as n
        from base
        group by 1, 2
        order by stage, status
        """
    )

    rows = cur.fetchall()
    if not rows:
        print("No rows found in DBT_TEST_RESULTS for invocation_id.")
        return

    # Print in a simple aligned format
    for stage, status, n in rows:
        print(f"{stage:28s} {status:10s} {n}")

    cur.execute(
        f"""
        with base as (
            select
                resource_path,
                status
            from DBT_TEST_RESULTS
            where invocation_id = '{invocation_id}'
        ),
        classified as (
            select
                resource_path,
                status,
                case
                    when resource_path ilike '%tests/staging%' or resource_path ilike '%tests\\staging\\%' then 'staging'
                    when resource_path ilike '%tests/intermediate%' or resource_path ilike '%tests\\intermediate\\%' then 'intermediate'
                    when resource_path ilike '%tests/marts%' or resource_path ilike '%tests\\marts\\%' then 'marts'
                    when resource_path ilike '%tests/reporting%' or resource_path ilike '%tests\\reporting\\%' then 'reporting'
                    when resource_path ilike '%models/marts%' or resource_path ilike '%models\\marts\\%' then 'marts (schema tests)'
                    when resource_path ilike '%models/reporting%' or resource_path ilike '%models\\reporting\\%' then 'reporting (schema tests)'
                    else 'other'
                end as stage
            from base
        )
        select
            resource_path,
            status,
            count(*) as n
        from classified
        where stage = 'other'
        group by 1,2
        order by n desc
        limit 10
        """
    )
    other_rows = cur.fetchall()
    if other_rows:
        print("\nTop 'other' resource_path values:")
        for rp, status, n in other_rows:
            print(f"{status:10s} {n:5d}  {rp}")

    cur.execute(
        f"""
        select
            count(*) as total_tests,
            sum(case when status = 'pass' then 1 else 0 end) as passes,
            sum(case when status in ('fail','error') then 1 else 0 end) as fails
        from DBT_TEST_RESULTS
        where invocation_id = '{invocation_id}'
        """
    )
    total_tests, passes, fails = cur.fetchone()
    print("total_tests:", total_tests, "passes:", passes, "fails:", fails)

    conn.close()


if __name__ == "__main__":
    main()

