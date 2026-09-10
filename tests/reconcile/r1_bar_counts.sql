-- Plan Phase 3 reconciliation, row 1: bars per contract after cleaning (compat rule set) equal
-- the reference interim files (5,946,851 in total).
WITH reference AS (
    SELECT
        regexp_extract(filename, '([a-z_0-9]+)\.parquet$', 1) AS slug,
        count(*) AS n_reference
    FROM read_parquet('data/reference/interim/*.parquet', filename = TRUE)
    GROUP BY slug
),

mine AS (
    SELECT
        slug,
        count(*) AS n_mine
    FROM clean.bars_all
    WHERE rule_set = 'compat'
    GROUP BY slug
)

SELECT
    m.n_mine,
    r.n_reference,
    coalesce(m.slug, r.slug) AS slug
FROM mine AS m
FULL OUTER JOIN reference AS r ON m.slug = r.slug
WHERE m.n_mine IS DISTINCT FROM r.n_reference;
