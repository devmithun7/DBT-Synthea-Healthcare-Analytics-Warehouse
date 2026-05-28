select *
from {{ ref('int_synthea__encounter_enriched') }}
where total_claim_cost is not null
  and encounter_payer_coverage is not null
  and encounter_payer_coverage > total_claim_cost
