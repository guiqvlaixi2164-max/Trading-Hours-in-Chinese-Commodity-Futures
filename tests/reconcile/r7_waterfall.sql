-- Beyond the plan's table: every step of the compat waterfall equals the reference cleaning
-- report, per contract. n_outliers_zeroed in the report counts flags before dead days are
-- removed (DECISIONS.md, entry 16), which is n_outliers_flagged here.
WITH reference AS (
    SELECT *
    FROM read_csv('data/reference/cleaning_report.csv', header = TRUE)
)

SELECT
    r.slug,
    w.n_after_session,
    r.n_after_session AS ref_n_after_session,
    w.n_after_zero_rv,
    r.n_after_zero_rv AS ref_n_after_zero_rv,
    w.n_outliers_flagged,
    r.n_outliers_zeroed AS ref_n_outliers_zeroed
FROM reference AS r
LEFT JOIN core.cleaning_waterfall AS w
    ON r.slug = w.slug AND w.rule_set = 'compat'
WHERE
    w.slug IS NULL
    OR w.n_raw <> r.n_raw
    OR w.n_after_ohlc <> r.n_after_ohlc
    OR w.n_after_session <> r.n_after_session
    OR w.n_after_volume_floor <> r.n_after_volume_floor
    OR w.n_after_min_bars <> r.n_after_min_bars
    OR w.n_after_zero_rv <> r.n_after_zero_rv
    OR w.n_off_session_bars <> r.n_off_session_bars
    OR w.n_unassigned_bars <> r.n_unassigned_bars
    OR w.n_outliers_flagged <> r.n_outliers_zeroed
    OR w.n_trading_days <> r.n_trading_days
    OR w.n_rollover_days <> r.n_rollover_candidates
    OR abs(w.daily_volume_floor - r.daily_volume_floor)
    > getvariable('rv_rel_tol') * abs(r.daily_volume_floor);
