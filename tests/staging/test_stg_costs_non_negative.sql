with invalid_rows as (
    select 'encounters.total_claim_cost' as metric_name, total_claim_cost as metric_value
    from {{ ref('stg_synthea__encounters') }}
    where total_claim_cost < 0

    union all

    select 'encounters.base_encounter_cost' as metric_name, base_encounter_cost as metric_value
    from {{ ref('stg_synthea__encounters') }}
    where base_encounter_cost < 0

    union all

    select 'medications.medication_total_cost' as metric_name, medication_total_cost as metric_value
    from {{ ref('stg_synthea__medications') }}
    where medication_total_cost < 0

    union all

    select 'medications.medication_base_cost' as metric_name, medication_base_cost as metric_value
    from {{ ref('stg_synthea__medications') }}
    where medication_base_cost < 0

    union all

    select 'procedures.procedure_base_cost' as metric_name, procedure_base_cost as metric_value
    from {{ ref('stg_synthea__procedures') }}
    where procedure_base_cost < 0
)
select *
from invalid_rows
