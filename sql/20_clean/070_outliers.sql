-- Step 7, outlier repair: a robust z-score against a centred rolling median, in two passes over
-- each contract's whole bar sequence (partitioned by contract only, not by day or block).
--   pass 1  med  = rolling median of ret over rows
--                  [seq - mad_window_before, seq + mad_window_after], NULLs ignored;
--                  NULL unless the frame holds `mad_min_periods` returns
--                  (pandas rolling(60, center=True, min_periods=15)).
--   pass 2  mad  = rolling median of |ret - med| over the same frame, same minimum.
--   threshold    = mad_k * mad_to_sigma * greatest(mad, mad_floor_frac * global_mad), where
--                  global_mad = median(|ret - median(ret)|) over the contract.
--   is_outlier   = |ret - med| > threshold, with threshold > 0.
-- A flagged return is set to 0 (ret_raw keeps the original); the bar stays.
CREATE OR REPLACE TABLE clean.bars_flagged AS
WITH returns AS MATERIALIZED (
    SELECT * FROM clean.bars_returns
),

global_median AS (
    SELECT
        rule_set,
        slug,
        median(ret) AS median_ret
    FROM returns
    GROUP BY rule_set, slug
),

global_mad AS (
    SELECT
        r.rule_set,
        r.slug,
        median(abs(r.ret - g.median_ret)) AS global_mad
    FROM returns AS r
    INNER JOIN global_median AS g ON r.rule_set = g.rule_set AND r.slug = g.slug
    GROUP BY r.rule_set, r.slug
),

pass1 AS (
    SELECT
        *,
        CASE
            WHEN count(ret) OVER w >= getvariable('mad_min_periods') THEN median(ret) OVER w
        END AS med
    FROM returns
    WINDOW w AS (
        PARTITION BY rule_set, slug ORDER BY seq
        -- SQLFluff's DuckDB grammar cannot parse variable frame bounds; DuckDB can.
        ROWS BETWEEN getvariable('mad_window_before') PRECEDING  -- noqa: PRS
        AND getvariable('mad_window_after') FOLLOWING
    )
),

pass2 AS (
    SELECT
        *,
        CASE
            WHEN count(abs(ret - med)) OVER w >= getvariable('mad_min_periods')
                THEN median(abs(ret - med)) OVER w
        END AS mad
    FROM pass1
    WINDOW w AS (
        PARTITION BY rule_set, slug ORDER BY seq
        -- SQLFluff's DuckDB grammar cannot parse variable frame bounds; DuckDB can.
        ROWS BETWEEN getvariable('mad_window_before') PRECEDING  -- noqa: PRS
        AND getvariable('mad_window_after') FOLLOWING
    )
),

flagged AS (
    SELECT
        p.*,
        g.global_mad,
        getvariable('mad_k') * getvariable('mad_to_sigma')
        * greatest(p.mad, getvariable('mad_floor_frac') * g.global_mad) AS threshold
    FROM pass2 AS p
    INNER JOIN global_mad AS g ON p.rule_set = g.rule_set AND p.slug = g.slug
)

SELECT
    p.* EXCLUDE (ret),
    p.ret AS ret_raw,
    coalesce(
        p.mad IS NOT NULL AND p.threshold > 0 AND abs(p.ret - p.med) > p.threshold, FALSE
    ) AS is_outlier,
    CASE WHEN is_outlier THEN 0.0 ELSE p.ret END AS ret
FROM flagged AS p
ORDER BY p.rule_set, p.slug, p.seq;
