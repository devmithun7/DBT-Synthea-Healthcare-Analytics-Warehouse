select *
from {{ ref('stg_synthea__encounters') }}
where ended_at is not null
  and started_at is not null
  and ended_at < started_at
