select *
from {{ ref('stg_synthea__payers') }}
where amount_covered < 0
   or amount_uncovered < 0
   or payer_revenue < 0

