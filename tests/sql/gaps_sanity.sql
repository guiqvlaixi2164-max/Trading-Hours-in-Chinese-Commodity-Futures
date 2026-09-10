-- core.gaps: one gap between each pair of consecutive blocks, every gap has positive length, a
-- type and a return, and a gap typed as a closure carries the closure's length.
WITH counts AS (
    SELECT
        b.slug,
        count(*) - 1 AS n_expected,
        (
            SELECT count(*) FROM core.gaps AS g
            WHERE g.slug = b.slug
        ) AS n_gaps
    FROM core.day_blocks AS b
    GROUP BY b.slug
)

SELECT
    'gap count differs from blocks - 1' AS problem,
    slug,
    NULL::TIMESTAMP AS gap_start
FROM counts
WHERE n_expected <> n_gaps

UNION ALL

SELECT
    'bad gap' AS problem,
    slug,
    gap_start
FROM core.gaps
WHERE
    gap_hours <= 0
    OR gap_type IS NULL
    OR ret_gap IS NULL
    OR (gap_type IN ('weekend', 'holiday', 'suspension') AND closure_calendar_days IS NULL);
