-- Plan Phase 4, step 5 test: core.fct_day reconciles with rv_panel. ret_cc against ret_d
-- (close-to-close return) within `ret_abs_tol`, rv_total against rv within `rv_rel_tol`, and the
-- same volume, closing open interest and flags. Checked on the contracts that are identical under
-- both rule sets (every contract but methanol, sugar and soybean No.2; core.cleaning_departures),
-- so the test holds whichever rule set the build used; r5 covers the other three in compat.
WITH same_contracts AS (
    SELECT slug
    FROM core.cleaning_departures
    WHERE
        d_bars = 0
        AND d_days = 0
        AND n_outliers_compat = n_outliers_session_aware
        AND n_rollover_compat = n_rollover_session_aware
        AND n_stale_compat = n_stale_session_aware
),

reference AS (
    SELECT
        slug,
        date::DATE AS trading_day,
        ret_d,
        rv,
        volume,
        position,
        is_rollover,
        is_stale
    FROM read_parquet('data/reference/rv_panel.parquet')
    WHERE slug IN (SELECT s.slug FROM same_contracts AS s)
)

SELECT
    f.ret_cc,
    r.ret_d,
    f.rv_total,
    r.rv,
    coalesce(f.slug, r.slug) AS slug,
    coalesce(f.trading_day, r.trading_day) AS trading_day
FROM (
    SELECT * FROM core.fct_day
    WHERE slug IN (SELECT s.slug FROM same_contracts AS s)
) AS f
FULL OUTER JOIN reference AS r ON f.slug = r.slug AND f.trading_day = r.trading_day
WHERE
    f.slug IS NULL
    OR r.slug IS NULL
    OR (f.ret_cc IS NULL) <> (r.ret_d IS NULL)
    OR abs(f.ret_cc - r.ret_d) > getvariable('ret_abs_tol')
    OR abs(f.rv_total - r.rv) > getvariable('rv_rel_tol') * abs(r.rv)
    OR f.volume_total <> r.volume
    OR f.oi_close <> r.position
    OR f.is_rollover <> r.is_rollover
    OR f.is_stale <> r.is_stale;
