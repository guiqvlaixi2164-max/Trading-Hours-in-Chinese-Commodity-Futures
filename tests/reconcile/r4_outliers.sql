-- Plan Phase 3 reconciliation, row 4: identical outlier flags (8,845 on the remaining bars).
WITH reference AS (
    SELECT
        regexp_extract(filename, '([a-z_0-9]+)\.parquet$', 1) AS slug,
        datetime AS ts,
        is_outlier
    FROM read_parquet('data/reference/interim/*.parquet', filename = TRUE)
)

SELECT
    m.slug,
    m.ts,
    m.is_outlier AS mine_is_outlier,
    r.is_outlier AS reference_is_outlier,
    m.ret_raw
FROM clean.bars_all AS m
INNER JOIN reference AS r ON m.slug = r.slug AND m.ts = r.ts
WHERE m.rule_set = 'compat' AND m.is_outlier <> r.is_outlier;
