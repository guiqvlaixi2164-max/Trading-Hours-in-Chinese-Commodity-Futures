-- The deliberate departure from the companion pipeline (plan Phase 3): session_aware keeps every
-- night bar the exchange printed; compat keeps only bars inside the companion's fixed template.
-- One row per contract, counts under both rule sets and their difference. Exported to
-- outputs/tables/cleaning_departures.csv.
CREATE OR REPLACE TABLE core.cleaning_departures AS
WITH night AS (
    SELECT
        rule_set,
        slug,
        count(*) FILTER (WHERE block = 'night') AS n_night_bars
    FROM clean.bars_all
    GROUP BY rule_set, slug
),

w AS (
    SELECT
        wf.*,
        n.n_night_bars
    FROM core.cleaning_waterfall AS wf
    INNER JOIN night AS n ON wf.rule_set = n.rule_set AND wf.slug = n.slug
),

c AS (
    SELECT * FROM w
    WHERE rule_set = 'compat'
),

s AS (
    SELECT * FROM w
    WHERE rule_set = 'session_aware'
)

SELECT
    c.slug,
    c.n_off_session_bars AS n_off_session_compat,
    s.n_off_session_bars AS n_off_session_session_aware,
    c.n_after_zero_rv AS n_bars_compat,
    s.n_after_zero_rv AS n_bars_session_aware,
    s.n_after_zero_rv - c.n_after_zero_rv AS d_bars,
    c.n_night_bars AS n_night_bars_compat,
    s.n_night_bars AS n_night_bars_session_aware,
    s.n_night_bars - c.n_night_bars AS d_night_bars,
    c.n_trading_days AS n_days_compat,
    s.n_trading_days AS n_days_session_aware,
    s.n_trading_days - c.n_trading_days AS d_days,
    c.n_outliers_final AS n_outliers_compat,
    s.n_outliers_final AS n_outliers_session_aware,
    c.n_rollover_days AS n_rollover_compat,
    s.n_rollover_days AS n_rollover_session_aware,
    c.n_stale_days AS n_stale_compat,
    s.n_stale_days AS n_stale_session_aware
FROM c
INNER JOIN s ON c.slug = s.slug
ORDER BY c.slug;
