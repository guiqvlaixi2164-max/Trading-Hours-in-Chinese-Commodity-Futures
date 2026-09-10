-- Exchange trading calendars: the union of the contracts' own trading days (days with
-- day-session bars, before any day is removed in cleaning), per exchange group (SHFE with INE,
-- DCE, CZCE) and across all exchanges ('ALL').
CREATE OR REPLACE TABLE core.exchange_calendar AS
WITH contract_days AS (
    SELECT DISTINCT
        c.exchange_group,
        k.trading_date AS trading_day
    FROM clean.contract_calendar AS k
    INNER JOIN core.contracts AS c ON k.slug = c.slug
    WHERE
        k.rule_set
        = CASE WHEN getvariable('compat_mode') THEN 'compat' ELSE 'session_aware' END
),

days AS (
    SELECT
        exchange_group,
        trading_day
    FROM contract_days
    UNION
    SELECT
        'ALL' AS exchange_group,
        trading_day
    FROM contract_days
)

SELECT
    exchange_group,
    trading_day,
    lag(trading_day) OVER w AS prev_trading_day,
    lead(trading_day) OVER w AS next_trading_day
FROM days
WINDOW w AS (PARTITION BY exchange_group ORDER BY trading_day)
ORDER BY exchange_group, trading_day;
