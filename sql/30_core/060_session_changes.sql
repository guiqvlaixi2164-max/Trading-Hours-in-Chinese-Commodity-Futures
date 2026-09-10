-- Session change points per contract (plan Phase 4, step 1):
--   adoption    first trading day with a night session (core.contract_sessions)
--   suspension  `suspension_min_days` or more trading days in a row without night bars after
--               adoption; trading_day is the first day without, last_day the last
--   shortening  the night end (last night bar, as a slot key) changes to an earlier / later time
--   extension   and the new end holds for `night_end_min_days` night days in a row. Runs are
--               counted over night days only, so a suspension does not break them.
CREATE OR REPLACE TABLE core.session_changes AS
WITH days AS (
    SELECT
        d.slug,
        d.trading_day,
        n.last_slot_key AS night_end_key
    FROM clean.days AS d
    INNER JOIN core.contract_sessions AS s
        ON d.slug = s.slug AND d.trading_day >= s.adoption_day
    LEFT JOIN core.day_blocks AS n
        ON d.slug = n.slug AND d.trading_day = n.trading_day AND n.block = 'night'
),

no_night AS (
    SELECT
        slug,
        trading_day,
        row_number() OVER (PARTITION BY slug ORDER BY trading_day)
        - row_number() OVER (PARTITION BY slug, night_end_key IS NULL ORDER BY trading_day) AS run
    FROM days
    QUALIFY night_end_key IS NULL
),

suspensions AS (
    SELECT
        slug,
        min(trading_day) AS trading_day,
        max(trading_day) AS last_day,
        count(*) AS n_days
    FROM no_night
    GROUP BY slug, run
    HAVING count(*) >= getvariable('suspension_min_days')
),

night_days AS (
    SELECT
        slug,
        trading_day,
        night_end_key,
        row_number() OVER (PARTITION BY slug ORDER BY trading_day)
        - row_number() OVER (PARTITION BY slug, night_end_key ORDER BY trading_day) AS run
    FROM days
    WHERE night_end_key IS NOT NULL
),

stable_ends AS (
    SELECT
        slug,
        night_end_key,
        min(trading_day) AS trading_day,
        count(*) AS n_days
    FROM night_days
    GROUP BY slug, night_end_key, run
    HAVING count(*) >= getvariable('night_end_min_days')
),

end_changes AS (
    SELECT
        *,
        lag(night_end_key) OVER (PARTITION BY slug ORDER BY trading_day) AS from_end_key
    FROM stable_ends
)

SELECT
    slug,
    'adoption' AS change_type,
    adoption_day AS trading_day,
    NULL::DATE AS last_day,
    NULL::BIGINT AS n_days,
    NULL::BIGINT AS from_end_key,
    NULL::BIGINT AS to_end_key
FROM core.contract_sessions
WHERE has_night_session

UNION ALL

SELECT
    slug,
    'suspension' AS change_type,
    trading_day,
    last_day,
    n_days,
    NULL::BIGINT AS from_end_key,
    NULL::BIGINT AS to_end_key
FROM suspensions

UNION ALL

SELECT
    slug,
    CASE WHEN night_end_key < from_end_key THEN 'shortening' ELSE 'extension' END AS change_type,
    trading_day,
    NULL::DATE AS last_day,
    n_days,
    from_end_key,
    night_end_key AS to_end_key
FROM end_changes
WHERE from_end_key <> night_end_key

ORDER BY slug, trading_day, change_type;
