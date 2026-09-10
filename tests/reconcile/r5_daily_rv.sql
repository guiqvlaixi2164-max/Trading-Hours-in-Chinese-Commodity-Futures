-- Plan Phase 3 reconciliation, row 5: the same 90,835 contract-days, daily RV (sum of squared
-- ret) within relative `rv_rel_tol` of rv_panel.rv, and the same daily counts and closing values.
WITH reference AS (
    SELECT
        slug,
        date::DATE AS trading_day,
        rv,
        n_bars,
        n_returns,
        n_nonzero,
        n_outliers,
        volume,
        close,
        position
    FROM read_parquet('data/reference/rv_panel.parquet')
),

mine AS (
    SELECT *
    FROM clean.days_all
    WHERE rule_set = 'compat'
)

SELECT
    m.rv AS mine_rv,
    r.rv AS reference_rv,
    coalesce(m.slug, r.slug) AS slug,
    coalesce(m.trading_day, r.trading_day) AS trading_day
FROM mine AS m
FULL OUTER JOIN reference AS r ON m.slug = r.slug AND m.trading_day = r.trading_day
WHERE
    m.slug IS NULL
    OR r.slug IS NULL
    OR abs(m.rv - r.rv) > getvariable('rv_rel_tol') * abs(r.rv)
    OR m.n_bars <> r.n_bars
    OR m.n_returns <> r.n_returns
    OR m.n_nonzero <> r.n_nonzero
    OR m.n_outliers <> r.n_outliers
    OR m.volume <> r.volume
    OR m.close <> r.close
    OR m.position <> r.position;
