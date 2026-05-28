select *
from {{ ref('int_synthea__readmission_flags') }}
where is_7_day_readmission = 'Yes'
  and is_30_day_readmission = 'No'

union all

select *
from {{ ref('int_synthea__readmission_flags') }}
where is_30_day_readmission = 'Yes'
  and is_90_day_readmission = 'No'

union all

select *
from {{ ref('int_synthea__readmission_flags') }}
where has_readmission = 'No'
  and (
      is_7_day_readmission = 'Yes'
      or is_30_day_readmission = 'Yes'
      or is_90_day_readmission = 'Yes'
  )
