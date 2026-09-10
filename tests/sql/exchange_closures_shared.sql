-- Every long closure (>= holiday_min_calendar_days) of an exchange group is also a closure of
-- the all-exchange calendar with the same dates, or is listed in seeds/closure_exceptions.csv
-- (plan Phase 4, step 2 test). Listed exceptions must still occur.
WITH group_long AS (
    SELECT
        exchange_group,
        last_open_day,
        next_open_day
    FROM core.exchange_closures
    WHERE exchange_group <> 'ALL' AND is_long_closure
),

all_closures AS (
    SELECT
        last_open_day,
        next_open_day
    FROM core.exchange_closures
    WHERE exchange_group = 'ALL'
)

SELECT
    'group closure not shared and not an exception' AS problem,
    g.exchange_group,
    g.last_open_day,
    g.next_open_day
FROM group_long AS g
ANTI JOIN all_closures AS a
    ON g.last_open_day = a.last_open_day AND g.next_open_day = a.next_open_day
ANTI JOIN seed.closure_exceptions AS x
    ON
        g.exchange_group = x.exchange_group
        AND g.last_open_day = x.last_open_day
        AND g.next_open_day = x.next_open_day

UNION ALL

SELECT
    'listed exception does not occur' AS problem,
    x.exchange_group,
    x.last_open_day,
    x.next_open_day
FROM seed.closure_exceptions AS x
ANTI JOIN group_long AS g
    ON
        x.exchange_group = g.exchange_group
        AND x.last_open_day = g.last_open_day
        AND x.next_open_day = g.next_open_day;
