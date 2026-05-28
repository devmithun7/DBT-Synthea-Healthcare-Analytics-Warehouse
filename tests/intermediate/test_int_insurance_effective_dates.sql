select *
from {{ ref('int_synthea__patient_insurance_periods') }}
where effective_from > effective_to
