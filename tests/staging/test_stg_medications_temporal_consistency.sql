select *
from {{ ref('stg_synthea__medications') }}
where stopped_at is not null
  and started_at is not null
  and stopped_at < started_at
