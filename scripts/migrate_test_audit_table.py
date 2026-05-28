"""One-off migration script to add extra metadata columns to DBT_TEST_RESULTS."""

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
    for col, sql_type in [
        ("TARGET_MODEL_UNIQUE_ID", "varchar"),
        ("TARGET_MODEL_NAME", "varchar"),
        ("TARGET_MODEL_RESOURCE_TYPE", "varchar"),
        ("TARGET_MODEL_SCHEMA", "varchar"),
        ("MODEL_LAYER", "varchar"),
        ("PROFILE_DEFAULT_SCHEMA", "varchar"),
        ("DEPENDS_ON_NODES", "varchar"),
    ]:
        cur.execute(
            f"alter table if exists DBT_TEST_RESULTS "
            f"add column if not exists {col} {sql_type}"
        )
    conn.close()


if __name__ == "__main__":
    main()

