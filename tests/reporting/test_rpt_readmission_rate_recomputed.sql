with base as (
    select
        year_month,
        primary_diagnosis,
        payer_name,
        discharge_count,
        readmission_30day_rate_pct
    from {{ ref('rpt_synthea__readmission_rate_monthly') }}
),
recomputed as (
    select
        year_month,
        primary_diagnosis,
        payer_name,
        discharge_count,
        readmission_30day_rate_pct,
        /* recompute rate as readmissions / discharges * 100 */
        (discharge_count * (readmission_30day_rate_pct / 100.0)) as implied_readmissions
    from base
),
invalid_rows as (
    select *
    from recomputed
    where discharge_count > 0
      and (
        readmission_30day_rate_pct < 0
        or readmission_30day_rate_pct > 100
      )
)

select *
from invalid_rows
