-- Bars per contract in stg.bars equal the reference pipeline's n_raw (6,014,790 in total).
-- Returns every contract whose count differs or is missing on either side.
WITH staged AS (
    SELECT
        slug,
        count(*) AS n_staged
    FROM stg.bars
    GROUP BY slug
),

reference AS (
    SELECT
        slug,
        n_raw
    FROM read_csv('data/reference/cleaning_report.csv', header = true)
)

SELECT
    s.n_staged,
    r.n_raw,
    coalesce(s.slug, r.slug) AS slug
FROM staged AS s
FULL OUTER JOIN reference AS r ON s.slug = r.slug
WHERE s.n_staged IS DISTINCT FROM r.n_raw;
