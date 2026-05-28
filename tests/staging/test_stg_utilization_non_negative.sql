with invalid_rows as (
    select 'organizations.organization_utilization' as metric_name, organization_utilization as metric_value
    from {{ ref('stg_synthea__organizations') }}
    where organization_utilization < 0

    union all

    select 'providers.provider_utilization' as metric_name, provider_utilization as metric_value
    from {{ ref('stg_synthea__providers') }}
    where provider_utilization < 0
)
select *
from invalid_rows
