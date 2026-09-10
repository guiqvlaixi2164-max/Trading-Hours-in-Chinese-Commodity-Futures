-- Calendar days over the data's span, with exchange-open flags, closure labels, and US and UK
-- daylight saving (plan Phase 4, step 7).
--   us_dst / uk_bst  New York / London observe summer time at 12:00 local on that date, from
--                    the ICU time-zone database: the date's UTC offset is above the year's
--                    lowest (standard-time) offset. Checked against the statutory rules in
--                    tests/sql/dim_date_dst.sql.
--   closure_*        for closed days, the all-exchange closure they fall in
CREATE OR REPLACE TABLE core.dim_date AS
WITH bounds AS (
    SELECT
        min(cal_date) AS first_date,
        max(cal_date) AS last_date
    FROM stg.bars
),

spine AS (
    SELECT unnest(generate_series(first_date, last_date, INTERVAL 1 DAY))::DATE AS date
    FROM bounds
),

offsets AS (
    SELECT
        date,
        -- Noon local avoids the 02:00 switch hour.
        (date + INTERVAL 12 HOUR)
        - ((date + INTERVAL 12 HOUR) AT TIME ZONE 'America/New_York' AT TIME ZONE 'UTC')
            AS ny_offset,
        (date + INTERVAL 12 HOUR)
        - ((date + INTERVAL 12 HOUR) AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC')
            AS london_offset
    FROM spine
),

open_days AS (
    SELECT
        trading_day,
        bool_or(exchange_group = 'ALL') AS is_open_all,
        bool_or(exchange_group = 'SHFE') AS is_open_shfe,
        bool_or(exchange_group = 'DCE') AS is_open_dce,
        bool_or(exchange_group = 'CZCE') AS is_open_czce
    FROM core.exchange_calendar
    GROUP BY trading_day
)

SELECT
    o.date,
    year(o.date) AS year,
    quarter(o.date) AS quarter,
    month(o.date) AS month,
    strftime(o.date, '%Y-%m') AS year_month,
    isodow(o.date) AS iso_dow,
    dayname(o.date) AS day_name,
    isodow(o.date) >= 6 AS is_weekend,
    coalesce(d.is_open_all, FALSE) AS is_exchange_open,
    coalesce(d.is_open_shfe, FALSE) AS is_open_shfe,
    coalesce(d.is_open_dce, FALSE) AS is_open_dce,
    coalesce(d.is_open_czce, FALSE) AS is_open_czce,
    k.closure_type,
    k.holiday,
    k.calendar_days AS closure_calendar_days,
    coalesce(k.is_long_closure, FALSE) AS is_long_closure,
    o.ny_offset > min(o.ny_offset) OVER (PARTITION BY year(o.date)) AS us_dst,
    o.london_offset > min(o.london_offset) OVER (PARTITION BY year(o.date)) AS uk_bst,
    (o.ny_offset > min(o.ny_offset) OVER (PARTITION BY year(o.date)))
    <> (o.london_offset > min(o.london_offset) OVER (PARTITION BY year(o.date)))
        AS is_us_uk_mismatch
FROM offsets AS o
LEFT JOIN open_days AS d ON o.date = d.trading_day
LEFT JOIN core.exchange_closures AS k
    ON
        k.exchange_group = 'ALL'
        AND o.date BETWEEN k.first_closed_day AND k.last_closed_day
ORDER BY o.date;
