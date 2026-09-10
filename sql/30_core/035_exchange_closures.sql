-- Exchange closures: every run of calendar days without trading between two open days, per
-- exchange group.
--   calendar_days    next open day - last open day (Friday -> Monday = 3)
--   closure_type     weekend     no weekday is closed
--                    holiday     a weekday is closed and a rule in seed.holiday_rules matches
--                    suspension  a weekday is closed and no rule matches
--   holiday          descriptive label; the analysis uses calendar_days, not the name
--   is_long_closure  calendar_days >= holiday_min_calendar_days (the Part C holiday sample)
CREATE OR REPLACE TABLE core.exchange_closures AS
WITH closures AS (
    SELECT
        exchange_group,
        trading_day AS last_open_day,
        next_trading_day AS next_open_day,
        next_trading_day - trading_day AS calendar_days,
        trading_day + 1 AS first_closed_day,
        next_trading_day - 1 AS last_closed_day
    FROM core.exchange_calendar
    WHERE next_trading_day - trading_day > 1
),

closed_days AS (
    SELECT
        c.exchange_group,
        c.last_open_day,
        count(*) FILTER (WHERE isodow(d.day::DATE) <= 5) AS n_closed_weekdays
    FROM closures AS c,
        LATERAL (
            SELECT unnest(generate_series(c.first_closed_day, c.last_closed_day, INTERVAL 1 DAY))
                AS day
        ) AS d
    GROUP BY c.exchange_group, c.last_open_day
),

labels AS (
    SELECT
        c.exchange_group,
        c.last_open_day,
        arg_min(r.holiday, r.priority) AS holiday
    FROM closures AS c
    INNER JOIN seed.holiday_rules AS r
        ON
            (r.year IS NULL OR r.year = year(c.first_closed_day))
            AND c.calendar_days >= r.min_calendar_days
            AND CASE
                WHEN r.first_closed_from <= r.first_closed_to
                    THEN
                        strftime(c.first_closed_day, '%m-%d')
                        BETWEEN r.first_closed_from AND r.first_closed_to
                ELSE
                    strftime(c.first_closed_day, '%m-%d') >= r.first_closed_from
                    OR strftime(c.first_closed_day, '%m-%d') <= r.first_closed_to
            END
    GROUP BY c.exchange_group, c.last_open_day
)

SELECT
    c.*,
    w.n_closed_weekdays,
    CASE
        WHEN w.n_closed_weekdays = 0 THEN 'weekend'
        WHEN l.holiday IS NOT NULL THEN 'holiday'
        ELSE 'suspension'
    END AS closure_type,
    CASE WHEN w.n_closed_weekdays > 0 THEN l.holiday END AS holiday,
    c.calendar_days >= getvariable('holiday_min_calendar_days') AS is_long_closure
FROM closures AS c
INNER JOIN closed_days AS w
    ON c.exchange_group = w.exchange_group AND c.last_open_day = w.last_open_day
LEFT JOIN labels AS l
    ON c.exchange_group = l.exchange_group AND c.last_open_day = l.last_open_day
ORDER BY c.exchange_group, c.last_open_day;
