"""
Fetch MAX(_LOADED_AT) and null counts for RAW Synthea tables.
Used to validate dbt `source freshness` configuration.
"""

import os
import sys

import snowflake.connector


TABLES = [
    "CONDITIONS",
    "ENCOUNTERS",
    "MEDICATIONS",
    "ORGANIZATIONS",
    "PATIENTS",
    "PAYERS",
    "PAYER_TRANSITIONS",
    "PROCEDURES",
    "PROVIDERS",
]


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
        schema="RAW",
    )

    cur = conn.cursor()
    for t in TABLES:
        cur.execute(
            f"""
            select
              max(_LOADED_AT) as max_loaded_at,
              count_if(_LOADED_AT is null) as loaded_at_nulls,
              count(*) as total_rows
            from {t}
            """
        )
        row = cur.fetchone()
        print(t, row)

    conn.close()


if __name__ == "__main__":
    main()

