-- Plan Phase 3 reconciliation, row 2: the same (slug, ts) bars, each with the same trading day
-- and block, in the compat rule set and the reference interim files.
WITH reference AS (
    SELECT
        regexp_extract(filename, '([a-z_0-9]+)\.parquet$', 1) AS slug,
        datetime AS ts,
        trading_day::DATE AS trading_day,
        block
    FROM read_parquet('data/reference/interim/*.parquet', filename = TRUE)
),

mine AS (
    SELECT
        slug,
        ts,
        trading_day,
        block
    FROM clean.bars_all
    WHERE rule_set = 'compat'
)

SELECT
    m.trading_day AS mine_trading_day,
    r.trading_day AS reference_trading_day,
    m.block AS mine_block,
    r.block AS reference_block,
    coalesce(m.slug, r.slug) AS slug,
    coalesce(m.ts, r.ts) AS ts
FROM mine AS m
FULL OUTER JOIN reference AS r ON m.slug = r.slug AND m.ts = r.ts
WHERE
    m.slug IS NULL
    OR r.slug IS NULL
    OR m.trading_day <> r.trading_day
    OR m.block <> r.block;
