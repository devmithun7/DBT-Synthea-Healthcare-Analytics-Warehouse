"""Verify STAGING view columns in Snowflake match renamed staging models."""
import os
import sys

import snowflake.connector

TABLES = [
    "STG_SYNTHEA__PROVIDERS",
    "STG_SYNTHEA__PATIENTS",
    "STG_SYNTHEA__CONDITIONS",
]

EXPECTED = {
    "STG_SYNTHEA__PROVIDERS": [
        "PROVIDER_NAME",
        "ADDRESS_LINE_1",
        "ADDRESS_CITY",
        "PROVIDER_UTILIZATION",
    ],
    "STG_SYNTHEA__PATIENTS": [
        "FIRST_NAME",
        "HOME_ADDRESS_LINE_1",
        "PATIENT_GENDER",
    ],
    "STG_SYNTHEA__CONDITIONS": [
        "CONDITION_CODE",
        "CONDITION_DESCRIPTION",
    ],
}


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
        schema="STAGING",
    )
    cur = conn.cursor()
    ok = True
    for table in TABLES:
        cur.execute(
            """
            select column_name
            from information_schema.columns
            where table_catalog = 'SYNTHEA_WAREHOUSE'
              and table_schema = 'STAGING'
              and table_name = %s
            order by ordinal_position
            """,
            (table,),
        )
        columns = {row[0] for row in cur.fetchall()}
        print(f"\n{table} ({len(columns)} columns)")
        for col in EXPECTED[table]:
            present = col in columns
            status = "OK" if present else "MISSING"
            print(f"  [{status}] {col}")
            ok = ok and present
    conn.close()
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
