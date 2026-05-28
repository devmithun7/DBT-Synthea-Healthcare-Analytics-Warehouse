select *
from {{ ref('int_synthea__encounter_enriched') }}
where encounter_start_time is not null
  and encounter_stop_time is not null
  and encounter_stop_time < encounter_start_time
