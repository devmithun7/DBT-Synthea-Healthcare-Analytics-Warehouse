select
    patient_id,
    count(*) as current_count
from {{ ref('int_synthea__patient_insurance_periods') }}
where is_current = 'Yes'
group by patient_id
having count(*) > 1
