import os
import snowflake.connector

conn = snowflake.connector.connect(
    account="DCLVOWK-UW14956",
    user="DEVMITH",
    password=os.environ["SNOWFLAKE_PASSWORD"],
    role="ACCOUNTADMIN",
    database="SYNTHEA_WAREHOUSE",
    warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
)
cur = conn.cursor()
tables = [
    "RPT_SYNTHEA__MONTHLY_ENCOUNTERS",
    "RPT_SYNTHEA__READMISSION_RATE_MONTHLY",
    "RPT_SYNTHEA__COST_OF_CARE_ANNUAL",
    "RPT_SYNTHEA__PROVIDER_PERFORMANCE",
    "RPT_SYNTHEA__HIGH_RISK_PATIENTS",
]
for t in tables:
    cur.execute(f"select count(*) from reporting.{t}")
    print(f"{t}: {cur.fetchone()[0]}")

cur.execute(
    """
    select count(distinct patient_id)
    from intermediate.int_synthea__encounter_enriched
    """
)
print("distinct patients in encounters:", cur.fetchone()[0])

cur.execute(
    """
    select count(*)
    from staging.stg_synthea__conditions
    where stopped_at is null
    """
)
print("open conditions:", cur.fetchone()[0])

cur.execute("select is_current, count(*) from marts.dim_synthea__patient group by 1")
print("is_current dist:", cur.fetchall())
