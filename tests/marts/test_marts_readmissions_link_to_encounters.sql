with missing_index_encounters as (
    select
        fr.index_encounter_id
    from {{ ref('fct_synthea__readmissions') }} as fr
    left join {{ ref('fct_synthea__encounters') }} as fe
        on fr.index_encounter_id = fe.encounter_id
    where fe.encounter_id is null
)

select *
from missing_index_encounters
