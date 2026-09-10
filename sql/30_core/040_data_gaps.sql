-- Data gaps: days on which the contract's exchange group was open, inside the contract's own
-- cleaned date range, but the contract has no cleaned trading day. The reason is the first
-- cleaning step that removed the day, or no_day_session if it never had day-session bars.
CREATE OR REPLACE TABLE core.data_gaps AS
WITH expected AS (
    SELECT
        c.slug,
        e.trading_day
    FROM core.contracts AS c
    INNER JOIN core.exchange_calendar AS e
        ON
            c.exchange_group = e.exchange_group
            AND e.trading_day BETWEEN c.first_trading_day AND c.last_trading_day
),

missing AS (
    SELECT x.*
    FROM expected AS x
    ANTI JOIN clean.days AS d ON x.slug = d.slug AND x.trading_day = d.trading_day
),

active_volume AS (
    SELECT *
    FROM clean.day_volume
    WHERE
        rule_set
        = CASE WHEN getvariable('compat_mode') THEN 'compat' ELSE 'session_aware' END
),

active_dead AS (
    SELECT *
    FROM clean.days_dead
    WHERE
        rule_set
        = CASE WHEN getvariable('compat_mode') THEN 'compat' ELSE 'session_aware' END
)

SELECT
    m.slug,
    m.trading_day,
    CASE
        WHEN v.slug IS NULL THEN 'no_day_session'
        WHEN v.is_below_floor THEN 'below_volume_floor'
        WHEN v.n_bars < getvariable('min_bars_per_day') THEN 'too_few_bars'
        WHEN z.slug IS NOT NULL THEN 'zero_rv'
        ELSE 'unexplained'
    END AS reason
FROM missing AS m
LEFT JOIN active_volume AS v ON m.slug = v.slug AND m.trading_day = v.trading_day
LEFT JOIN active_dead AS z ON m.slug = z.slug AND m.trading_day = z.trading_day
ORDER BY m.slug, m.trading_day;
