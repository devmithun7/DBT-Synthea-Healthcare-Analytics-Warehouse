"""One-off script to fetch RAW schema column metadata from Snowflake."""
import json
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
    placeholders = ", ".join(["%s"] * len(TABLES))
    cur.execute(
        f"""
        SELECT table_name, column_name, data_type, ordinal_position, is_nullable
        FROM SYNTHEA_WAREHOUSE.INFORMATION_SCHEMA.COLUMNS
        WHERE table_schema = 'RAW'
          AND table_name IN ({placeholders})
        ORDER BY table_name, ordinal_position
        """,
        TABLES,
    )
    by_table: dict[str, list[dict]] = {}
    for table_name, column_name, data_type, ordinal_position, is_nullable in cur.fetchall():
        by_table.setdefault(table_name, []).append(
            {
                "column_name": column_name,
                "data_type": data_type,
                "ordinal_position": ordinal_position,
                "is_nullable": is_nullable,
            }
        )
    print(json.dumps(by_table, indent=2))
    conn.close()


if __name__ == "__main__":
    main()
