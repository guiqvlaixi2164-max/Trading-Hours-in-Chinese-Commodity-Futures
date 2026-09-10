-- Plan Phase 3 reconciliation, row 3: ret and gap_ret agree within `ret_abs_tol`, and are NULL
-- on the same bars. ret is compared after outlier repair (flagged returns are 0 on both sides).
WITH reference AS (
    SELECT
        regexp_extract(filename, '([a-z_0-9]+)\.parquet$', 1) AS slug,
        datetime AS ts,
        ret,
        gap_ret
    FROM read_parquet('data/reference/interim/*.parquet', filename = TRUE)
)

SELECT
    m.slug,
    m.ts,
    m.ret AS mine_ret,
    r.ret AS reference_ret,
    m.gap_ret AS mine_gap_ret,
    r.gap_ret AS reference_gap_ret
FROM clean.bars_all AS m
INNER JOIN reference AS r ON m.slug = r.slug AND m.ts = r.ts
WHERE
    m.rule_set = 'compat'
    AND (
        (m.ret IS NULL) <> (r.ret IS NULL)
        OR (m.gap_ret IS NULL) <> (r.gap_ret IS NULL)
        OR abs(m.ret - r.ret) > getvariable('ret_abs_tol')
        OR abs(m.gap_ret - r.gap_ret) > getvariable('ret_abs_tol')
    );
