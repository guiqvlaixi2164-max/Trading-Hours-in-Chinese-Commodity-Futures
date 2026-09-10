-- One row per cleaned contract-day: close-to-close return, realised variance by session, volume
-- by session, closing open interest, and the flags that define valid days (docs/HYPOTHESES.md §2).
--   ret_cc              ln(close / previous cleaned day's close), 15:00 to 15:00
--   rv_day, rv_night    sums of squared within-block returns (day blocks have the same hours in
--                       every session regime)
--   in_night_regime     on or after adoption and outside a suspension
--   night_cancelled     no contract of the exchange group that is in its night regime has a
--                       night block that day: the exchange did not hold a night session (for
--                       example 2024-01-22, 2017-03-31 at DCE)
--   night_expected      in_night_regime, the day does not follow a closure with a closed
--                       weekday (the exchange cancels the night session before a holiday), and
--                       the group's night session was not cancelled
--   is_complete_day     previous cleaned day is the exchange's previous open day (no data gap),
--                       all day blocks present, and a night block if one is expected
--   is_valid_return_day complete, and neither rollover nor limit (stale) day
CREATE OR REPLACE TABLE core.fct_day AS
WITH n_day_blocks AS (
    SELECT count(*) AS n
    FROM seed.session_blocks
    WHERE block <> 'night'
),

blocks AS (
    SELECT
        slug,
        trading_day,
        count(*) FILTER (WHERE block <> 'night') AS n_day_blocks,
        coalesce(bool_or(block = 'night'), FALSE) AS has_night_block,
        coalesce(sum(n_bars) FILTER (WHERE block = 'night'), 0) AS n_night_bars,
        max(last_slot_key) FILTER (WHERE block = 'night') AS night_end_key,
        coalesce(sum(volume) FILTER (WHERE block = 'night'), 0) AS volume_night,
        coalesce(sum(volume) FILTER (WHERE block <> 'night'), 0) AS volume_day,
        coalesce(sum(rv) FILTER (WHERE block = 'night'), 0) AS rv_night,
        coalesce(sum(rv) FILTER (WHERE block <> 'night'), 0) AS rv_day
    FROM core.day_blocks
    GROUP BY slug, trading_day
),

days AS (
    SELECT
        d.*,
        c.exchange_group,
        lag(d.trading_day) OVER w AS prev_trading_day,
        lag(d.close) OVER w AS prev_close
    FROM clean.days AS d
    INNER JOIN core.contracts AS c ON d.slug = c.slug
    WINDOW w AS (PARTITION BY d.slug ORDER BY d.trading_day)
),

suspended AS (
    SELECT
        d.slug,
        d.trading_day
    FROM clean.days AS d
    INNER JOIN core.session_changes AS s
        ON
            d.slug = s.slug
            AND s.change_type = 'suspension'
            AND d.trading_day BETWEEN s.trading_day AND s.last_day
),

flags AS (
    SELECT
        d.*,
        b.n_day_blocks,
        b.has_night_block,
        b.n_night_bars,
        b.night_end_key,
        b.volume_night,
        b.volume_day,
        b.rv_night,
        b.rv_day,
        e.prev_trading_day AS exchange_prev_day,
        k.closure_type AS preceding_closure_type,
        k.calendar_days AS preceding_closure_days,
        (d.prev_trading_day IS DISTINCT FROM e.prev_trading_day) AS is_after_data_gap,
        coalesce(
            cs.adoption_day IS NOT NULL
            AND d.trading_day >= cs.adoption_day
            AND sp.slug IS NULL,
            FALSE
        ) AS in_night_regime
    FROM days AS d
    INNER JOIN blocks AS b ON d.slug = b.slug AND d.trading_day = b.trading_day
    INNER JOIN core.contract_sessions AS cs ON d.slug = cs.slug
    LEFT JOIN core.exchange_calendar AS e
        ON d.exchange_group = e.exchange_group AND d.trading_day = e.trading_day
    LEFT JOIN core.exchange_closures AS k
        ON d.exchange_group = k.exchange_group AND d.trading_day = k.next_open_day
    LEFT JOIN suspended AS sp ON d.slug = sp.slug AND d.trading_day = sp.trading_day
),

group_nights AS (
    SELECT
        exchange_group,
        trading_day,
        count(*) FILTER (WHERE in_night_regime) > 0
        AND count(*) FILTER (WHERE in_night_regime AND has_night_block) = 0 AS night_cancelled
    FROM flags
    GROUP BY exchange_group, trading_day
)

SELECT
    f.slug,
    f.trading_day,
    f.prev_trading_day,
    f.exchange_prev_day,
    f.is_after_data_gap,
    f.preceding_closure_type,
    f.preceding_closure_days,
    ln(f.close / f.prev_close) AS ret_cc,
    ln(f.close / f.prev_close) ^ 2 AS sq_ret_cc,
    abs(ln(f.close / f.prev_close)) AS abs_ret_cc,
    f.rv AS rv_total,
    f.rv_day,
    f.rv_night,
    f.volume AS volume_total,
    f.volume_day,
    f.volume_night,
    f.position AS oi_close,
    f.close,
    f.n_bars,
    f.n_night_bars,
    f.has_night_block,
    f.night_end_key,
    f.in_night_regime,
    g.night_cancelled,
    f.in_night_regime
    AND coalesce(f.preceding_closure_type NOT IN ('holiday', 'suspension'), TRUE)
    AND NOT g.night_cancelled AS night_expected,
    f.prev_trading_day IS NOT NULL
    AND NOT f.is_after_data_gap
    AND f.n_day_blocks = n.n
    AND (f.has_night_block OR NOT night_expected) AS is_complete_day,
    f.r_overnight,
    f.is_rollover,
    f.is_stale,
    is_complete_day AND NOT f.is_rollover AND NOT f.is_stale AS is_valid_return_day
FROM flags AS f
INNER JOIN group_nights AS g
    ON f.exchange_group = g.exchange_group AND f.trading_day = g.trading_day
CROSS JOIN n_day_blocks AS n
ORDER BY f.slug, f.trading_day;
