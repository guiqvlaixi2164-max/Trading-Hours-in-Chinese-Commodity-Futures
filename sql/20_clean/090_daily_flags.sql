-- Step 9, one row per surviving contract-day and rule set, with the daily flags.
--   is_stale     fewer than `min_nonzero_returns` non-zero returns (limit days).
--   is_rollover  a main-contract switch in the spliced series:
--                  |r_overnight| > rollover_z * stddev_samp(r_overnight)
--                  AND |d_log_oi| > rollover_z * stddev_samp(|d_log_oi|),
--                where r_overnight is the day's first-bar gap return and d_log_oi the change in
--                log closing open interest from the previous day, both per contract. The
--                open-interest scale is the sd of the *absolute* change; that is what reproduces
--                the reference flags exactly (DECISIONS.md, entry 38).
CREATE OR REPLACE TABLE clean.days_all AS
WITH bars AS (
    SELECT f.*
    FROM clean.bars_flagged AS f
    ANTI JOIN clean.days_dead AS d
        ON f.rule_set = d.rule_set AND f.slug = d.slug AND f.trading_day = d.trading_day
),

daily AS (
    SELECT
        rule_set,
        slug,
        trading_day,
        count(*) AS n_bars,
        count(ret) AS n_returns,
        count(*) FILTER (WHERE ret <> 0) AS n_nonzero,
        count(DISTINCT block) AS n_blocks,
        count(*) FILTER (WHERE is_outlier) AS n_outliers,
        sum(ret * ret) AS rv,
        sum(volume) AS volume,
        -- close and position keep the bar columns' names.
        arg_max(close, seq) AS close,  -- noqa: RF04
        arg_max(position, seq) AS position,  -- noqa: RF04
        min(seq) AS first_seq
    FROM bars
    GROUP BY rule_set, slug, trading_day
),

first_bar AS (
    SELECT
        b.rule_set,
        b.slug,
        b.trading_day,
        b.gap_ret AS r_overnight
    FROM bars AS b
    INNER JOIN daily AS d
        ON
            b.rule_set = d.rule_set
            AND b.slug = d.slug
            AND b.trading_day = d.trading_day
            AND b.seq = d.first_seq
),

with_oi AS (
    SELECT
        d.* EXCLUDE (d.first_seq),
        f.r_overnight,
        ln(d.position) - lag(ln(d.position)) OVER (
            PARTITION BY d.rule_set, d.slug ORDER BY d.trading_day
        ) AS d_log_oi
    FROM daily AS d
    INNER JOIN first_bar AS f
        ON d.rule_set = f.rule_set AND d.slug = f.slug AND d.trading_day = f.trading_day
),

sd AS (
    SELECT
        rule_set,
        slug,
        stddev_samp(r_overnight) AS sd_r_overnight,
        stddev_samp(abs(d_log_oi)) AS sd_abs_d_log_oi
    FROM with_oi
    GROUP BY rule_set, slug
)

SELECT
    w.*,
    w.n_nonzero < getvariable('min_nonzero_returns') AS is_stale,
    coalesce(
        abs(w.r_overnight) > getvariable('rollover_z') * s.sd_r_overnight
        AND abs(w.d_log_oi) > getvariable('rollover_z') * s.sd_abs_d_log_oi,
        FALSE
    ) AS is_rollover
FROM with_oi AS w
INNER JOIN sd AS s ON w.rule_set = s.rule_set AND w.slug = s.slug
ORDER BY w.rule_set, w.slug, w.trading_day;
