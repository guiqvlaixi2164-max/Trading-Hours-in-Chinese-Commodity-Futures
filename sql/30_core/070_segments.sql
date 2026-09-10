-- The eight segment returns of each contract-day (plan Phase 4, step 4; seed.segments), built
-- from block opens and closes so that on a complete day they add up to ret_cc exactly:
--   pre_night_gap  ln(night first open / previous day's last close)       0 without a night block
--   night          ln(night last close / night first open)                0 without a night block
--   pre_day_gap    ln(09:00 first open / night last close, or previous close without a night block)
--   morning_1, morning_2, afternoon   ln(last close / first open) within the block
--   break_1015     ln(morning_2 first open / morning_1 last close)
--   lunch_gap      ln(afternoon first open / morning_2 last close)
-- The previous close is the contract's previous cleaned trading day. A segment whose blocks are
-- missing is NULL; such days are not complete (core.fct_day.is_complete_day).
CREATE OR REPLACE TABLE core.segments AS
WITH blocks AS (
    SELECT
        slug,
        trading_day,
        max(first_open) FILTER (WHERE block = 'night') AS night_open,
        max(last_close) FILTER (WHERE block = 'night') AS night_close,
        max(first_open) FILTER (WHERE block = 'morning_1') AS m1_open,
        max(last_close) FILTER (WHERE block = 'morning_1') AS m1_close,
        max(first_open) FILTER (WHERE block = 'morning_2') AS m2_open,
        max(last_close) FILTER (WHERE block = 'morning_2') AS m2_close,
        max(first_open) FILTER (WHERE block = 'afternoon') AS af_open,
        max(last_close) FILTER (WHERE block = 'afternoon') AS af_close
    FROM core.day_blocks
    GROUP BY slug, trading_day
),

days AS (
    SELECT
        b.*,
        lag(d.close) OVER (PARTITION BY d.slug ORDER BY d.trading_day) AS prev_close
    FROM clean.days AS d
    INNER JOIN blocks AS b ON d.slug = b.slug AND d.trading_day = b.trading_day
),

wide AS (
    SELECT
        slug,
        trading_day,
        CASE WHEN night_open IS NULL THEN 0.0 ELSE ln(night_open / prev_close) END
            AS pre_night_gap,
        CASE WHEN night_open IS NULL THEN 0.0 ELSE ln(night_close / night_open) END AS night,
        ln(m1_open / coalesce(night_close, prev_close)) AS pre_day_gap,
        ln(m1_close / m1_open) AS morning_1,
        ln(m2_open / m1_close) AS break_1015,
        ln(m2_close / m2_open) AS morning_2,
        ln(af_open / m2_close) AS lunch_gap,
        ln(af_close / af_open) AS afternoon
    FROM days
),

long AS (
    SELECT *
    FROM wide
    UNPIVOT INCLUDE NULLS (
        ret_seg FOR segment IN (
            pre_night_gap, night, pre_day_gap, morning_1, break_1015, morning_2, lunch_gap,
            afternoon
        )
    )
)

SELECT
    l.slug,
    l.trading_day,
    l.segment,
    s.segment_order,
    l.ret_seg
FROM long AS l
INNER JOIN seed.segments AS s ON l.segment = s.segment
ORDER BY l.slug, l.trading_day, s.segment_order;
