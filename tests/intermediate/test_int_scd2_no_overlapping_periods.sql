select
    p1.patient_id,
    p1.scd2_version,
    p2.scd2_version as overlapping_version,
    p1.effective_from,
    p1.effective_to,
    p2.effective_from as overlapping_effective_from
from {{ ref('int_synthea__patient_insurance_periods') }} as p1
inner join {{ ref('int_synthea__patient_insurance_periods') }} as p2
    on p1.patient_id = p2.patient_id
    and p1.scd2_version < p2.scd2_version
    and p1.effective_to >= p2.effective_from
