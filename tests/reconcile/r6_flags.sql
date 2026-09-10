-- Plan Phase 3 reconciliation, row 6: the same 199 rollover and 216 stale contract-days.
WITH reference AS (
    SELECT
        slug,
        date::DATE AS trading_day,
        is_rollover,
        is_stale
    FROM read_parquet('data/reference/rv_panel.parquet')
)

SELECT
    m.slug,
    m.trading_day,
    m.is_rollover AS mine_is_rollover,
    r.is_rollover AS reference_is_rollover,
    m.is_stale AS mine_is_stale,
    r.is_stale AS reference_is_stale
FROM clean.days_all AS m
INNER JOIN reference AS r ON m.slug = r.slug AND m.trading_day = r.trading_day
WHERE
    m.rule_set = 'compat'
    AND (m.is_rollover <> r.is_rollover OR m.is_stale <> r.is_stale);
