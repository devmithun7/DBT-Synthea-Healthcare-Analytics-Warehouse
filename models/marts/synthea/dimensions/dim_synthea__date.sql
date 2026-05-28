{{
    config(
        tags=['daily']
    )
}}

with generated as (

    select
        dateadd(day, seq4(), '1900-01-01'::date) as calendar_date
    from table(generator(rowcount => 47884))

),

date_spine as (

    select calendar_date
    from generated
    where calendar_date <= '2030-12-31'::date

),

final as (

    select
        {{ synthea_date_key('calendar_date') }} as date_key,
        calendar_date,
        extract(day from calendar_date) as day_of_month,
        dayname(calendar_date) as day_of_week,
        dayofweek(calendar_date) as day_of_week_num,
        weekofyear(calendar_date) as week_of_year,
        weekiso(calendar_date) as iso_week,
        extract(month from calendar_date) as month_num,
        monthname(calendar_date) as month_name,
        extract(quarter from calendar_date) as quarter_num,
        extract(year from calendar_date) as year_num,
        case
            when extract(month from calendar_date) >= 10
                then extract(year from calendar_date) + 1
            else extract(year from calendar_date)
        end as fiscal_year,
        case
            when extract(month from calendar_date) in (10, 11, 12) then 1
            when extract(month from calendar_date) in (1, 2, 3) then 2
            when extract(month from calendar_date) in (4, 5, 6) then 3
            else 4
        end as fiscal_quarter,
        to_char(calendar_date, 'YYYY-MM') as year_month,
        extract(year from calendar_date) || '-Q' || extract(quarter from calendar_date) as year_quarter,
        {{ synthea_yes_no_from_boolean("dayname(calendar_date) in ('Sat', 'Sun')") }} as is_weekend,
        {{ synthea_yes_no_from_boolean('extract(day from calendar_date) = 1') }} as is_month_start,
        {{ synthea_yes_no_from_boolean(
            'calendar_date = last_day(calendar_date)'
        ) }} as is_month_end,
        {{ dbt.current_timestamp_backcompat() }}::timestamp_ntz as dbt_loaded_at
    from date_spine

)

select * from final
