-- On complete days the eight segment returns add up to ret_cc within `segment_sum_tol`, and each
-- complete day has all eight segments (plan Phase 4, step 4 test).
WITH sums AS (
    SELECT
        slug,
        trading_day,
        sum(ret_seg) AS sum_seg,
        count(ret_seg) AS n_seg
    FROM core.segments
    GROUP BY slug, trading_day
)

SELECT
    f.slug,
    f.trading_day,
    f.ret_cc,
    s.sum_seg,
    s.n_seg
FROM core.fct_day AS f
LEFT JOIN sums AS s ON f.slug = s.slug AND f.trading_day = s.trading_day
WHERE
    f.is_complete_day
    AND (
        s.slug IS NULL
        OR s.n_seg <> (SELECT count(*) FROM seed.segments)
        OR abs(s.sum_seg - f.ret_cc) > getvariable('segment_sum_tol')
    );
