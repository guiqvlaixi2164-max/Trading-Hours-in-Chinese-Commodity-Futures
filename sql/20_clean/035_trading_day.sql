-- Step 3b, trading day.
--   Evening night bars (clock >= night open) belong to the first calendar date strictly after
--   their own date; post-midnight night bars to the first date on or after it; day bars keep
--   their own date.
--   Night bars with no following day session (trailing bars at the end of the data) find no
--   trading day and drop out here.
CREATE OR REPLACE TABLE clean.bars_day AS
WITH night_open AS (
    SELECT start_min AS night_open_min
    FROM seed.session_blocks
    WHERE block = 'night'
),

evening AS (
    SELECT
        b.*,
        c.trading_date AS trading_day
    FROM (
        SELECT bb.*
        FROM clean.bars_block AS bb, night_open AS n
        WHERE bb.block = 'night' AND bb.clock_min >= n.night_open_min
    ) AS b
    ASOF LEFT JOIN clean.contract_calendar AS c
        ON
            b.rule_set = c.rule_set
            AND b.slug = c.slug
            AND b.cal_date < c.trading_date
),

post_midnight AS (
    SELECT
        b.*,
        c.trading_date AS trading_day
    FROM (
        SELECT bb.*
        FROM clean.bars_block AS bb, night_open AS n
        WHERE bb.block = 'night' AND bb.clock_min < n.night_open_min
    ) AS b
    ASOF LEFT JOIN clean.contract_calendar AS c
        ON
            b.rule_set = c.rule_set
            AND b.slug = c.slug
            AND b.cal_date <= c.trading_date
),

day_bars AS (
    SELECT
        *,
        cal_date AS trading_day
    FROM clean.bars_block
    WHERE block <> 'night'
)

SELECT *
FROM (
    SELECT * FROM evening
    UNION ALL
    SELECT * FROM post_midnight
    UNION ALL
    SELECT * FROM day_bars
) AS assigned
WHERE trading_day IS NOT NULL
ORDER BY rule_set, slug, trading_day, block_order, ts;
