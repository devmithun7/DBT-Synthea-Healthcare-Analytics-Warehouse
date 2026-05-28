select *
from {{ ref('int_synthea__readmission_flags') }}
where readmit_encounter_id is not null
  and (
      readmit_date is null
      or readmit_date <= discharge_date
      or days_to_readmission < 0
  )
