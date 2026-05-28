"""Quick check for dbt test audit table contents."""

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
    cur.execute("select count(*) from DBT_TEST_RESULTS")
    print("total_rows", cur.fetchone()[0])

    cur.execute(
        """
        select invocation_id, test_name, status, failures, execution_time_seconds
        from DBT_TEST_RESULTS
        order by logged_at desc
        limit 10
        """
    )
    for row in cur.fetchall():
        print(row)

    conn.close()


if __name__ == "__main__":
    main()

