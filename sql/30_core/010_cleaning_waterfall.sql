-- Rows left after each cleaning step, per contract and rule set (for the Power BI data page and
-- the reconciliation against the reference cleaning report).
--   n_off_session_bars   bars outside every block window (step 2)
--   n_unassigned_bars    night bars with no following day session (step 3)
--   n_outliers_flagged   returns zeroed in step 7, counted before step 8 removes dead days
--   n_outliers_final     the same, on the bars that remain
CREATE OR REPLACE TABLE core.cleaning_waterfall AS
WITH rule_sets AS (
    SELECT DISTINCT
        rule_set,
        slug
    FROM clean.block_rules
),

raw_counts AS (
    SELECT
        slug,
        count(*) AS n_raw
    FROM stg.bars
    GROUP BY slug
),

ohlc_counts AS (
    SELECT
        slug,
        count(*) AS n_after_ohlc
    FROM clean.bars_ohlc
    GROUP BY slug
),

block_counts AS (
    SELECT
        rule_set,
        slug,
        count(*) AS n_in_block
    FROM clean.bars_block
    GROUP BY rule_set, slug
),

day_counts AS (
    SELECT
        rule_set,
        slug,
        sum(n_bars)::BIGINT AS n_after_session,
        (sum(n_bars) FILTER (WHERE NOT is_below_floor))::BIGINT AS n_after_volume_floor,
        any_value(volume_floor) AS daily_volume_floor
    FROM clean.day_volume
    GROUP BY rule_set, slug
),

kept_counts AS (
    SELECT
        v.rule_set,
        v.slug,
        sum(v.n_bars)::BIGINT AS n_after_min_bars
    FROM clean.day_volume AS v
    SEMI JOIN clean.days_kept AS k
        ON v.rule_set = k.rule_set AND v.slug = k.slug AND v.trading_day = k.trading_day
    GROUP BY v.rule_set, v.slug
),

flag_counts AS (
    SELECT
        rule_set,
        slug,
        count(*) FILTER (WHERE is_outlier) AS n_outliers_flagged
    FROM clean.bars_flagged
    GROUP BY rule_set, slug
),

final_counts AS (
    SELECT
        rule_set,
        slug,
        sum(n_outliers)::BIGINT AS n_outliers_final,
        count(*) AS n_trading_days,
        count(*) FILTER (WHERE is_rollover) AS n_rollover_days,
        count(*) FILTER (WHERE is_stale) AS n_stale_days,
        sum(n_bars)::BIGINT AS n_after_zero_rv
    FROM clean.days_all
    GROUP BY rule_set, slug
)

SELECT
    r.rule_set,
    r.slug,
    rc.n_raw,
    oc.n_after_ohlc,
    dc.n_after_session,
    dc.n_after_volume_floor,
    kc.n_after_min_bars,
    fc.n_after_zero_rv,
    oc.n_after_ohlc - bc.n_in_block AS n_off_session_bars,
    bc.n_in_block - dc.n_after_session AS n_unassigned_bars,
    flc.n_outliers_flagged,
    fc.n_outliers_final,
    fc.n_trading_days,
    fc.n_rollover_days,
    fc.n_stale_days,
    dc.daily_volume_floor
FROM rule_sets AS r
INNER JOIN raw_counts AS rc ON r.slug = rc.slug
INNER JOIN ohlc_counts AS oc ON r.slug = oc.slug
INNER JOIN block_counts AS bc ON r.rule_set = bc.rule_set AND r.slug = bc.slug
INNER JOIN day_counts AS dc ON r.rule_set = dc.rule_set AND r.slug = dc.slug
INNER JOIN kept_counts AS kc ON r.rule_set = kc.rule_set AND r.slug = kc.slug
INNER JOIN flag_counts AS flc ON r.rule_set = flc.rule_set AND r.slug = flc.slug
INNER JOIN final_counts AS fc ON r.rule_set = fc.rule_set AND r.slug = fc.slug
ORDER BY r.rule_set, r.slug;
