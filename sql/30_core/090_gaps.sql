-- Every non-trading interval per contract: from the end of a block's last bar (stamp + bar
-- length) to the next block's first bar, in trading order (plan Phase 4, step 6).
--   ret_gap    ln(first open after / last close before)
--   segment    the day segment the gap is (pre_night_gap, pre_day_gap, break_1015, lunch_gap);
--              NULL when a block in between is missing
--   gap_type   intraday_break  between two day blocks of the same trading day
--              data_gap        the contract misses open days of its exchange inside the gap
--              weekend / holiday / suspension
--                              the gap covers an exchange closure (core.exchange_closures): it
--                              starts before and ends after the closure's last closed day
--              overnight       any other gap between sessions
CREATE OR REPLACE TABLE core.gaps AS
WITH ordered AS (
    SELECT
        b.*,
        c.exchange_group,
        lag(b.block) OVER w AS prev_block,
        lag(b.trading_day) OVER w AS prev_trading_day,
        lag(b.last_ts) OVER w AS prev_last_ts,
        lag(b.last_close) OVER w AS prev_last_close
    FROM core.day_blocks AS b
    INNER JOIN core.contracts AS c ON b.slug = c.slug
    WINDOW w AS (PARTITION BY b.slug ORDER BY b.trading_day, b.block_order)
),

gaps AS (
    SELECT
        slug,
        exchange_group,
        prev_trading_day,
        trading_day,
        prev_block,
        block AS next_block,
        prev_last_ts + to_minutes(getvariable('bar_minutes')) AS gap_start,
        first_ts AS gap_end,
        ln(first_open / prev_last_close) AS ret_gap
    FROM ordered
    WHERE prev_block IS NOT NULL
)

SELECT
    g.slug,
    g.gap_start,
    g.gap_end,
    (epoch(g.gap_end) - epoch(g.gap_start)) / 3600.0 AS gap_hours,
    g.prev_trading_day,
    g.trading_day,
    g.prev_block,
    g.next_block,
    CASE
        WHEN
            g.trading_day = g.prev_trading_day AND g.prev_block = 'night'
            AND g.next_block = 'morning_1' THEN 'pre_day_gap'
        WHEN
            g.trading_day = g.prev_trading_day AND g.prev_block = 'morning_1'
            AND g.next_block = 'morning_2' THEN 'break_1015'
        WHEN
            g.trading_day = g.prev_trading_day AND g.prev_block = 'morning_2'
            AND g.next_block = 'afternoon' THEN 'lunch_gap'
        WHEN
            g.trading_day > g.prev_trading_day AND g.prev_block = 'afternoon'
            AND g.next_block = 'night' THEN 'pre_night_gap'
        WHEN
            g.trading_day > g.prev_trading_day AND g.prev_block = 'afternoon'
            AND g.next_block = 'morning_1' THEN 'pre_day_gap'
    END AS segment,
    CASE
        WHEN g.trading_day = g.prev_trading_day AND g.prev_block <> 'night' THEN 'intraday_break'
        WHEN g.trading_day > g.prev_trading_day AND g.prev_trading_day < e.prev_trading_day
            THEN 'data_gap'
        WHEN k.exchange_group IS NOT NULL THEN k.closure_type
        ELSE 'overnight'
    END AS gap_type,
    k.calendar_days AS closure_calendar_days,
    k.holiday,
    g.ret_gap
FROM gaps AS g
LEFT JOIN core.exchange_calendar AS e
    ON g.exchange_group = e.exchange_group AND g.trading_day = e.trading_day
LEFT JOIN core.exchange_closures AS k
    ON
        g.exchange_group = k.exchange_group
        AND g.trading_day = k.next_open_day
        AND g.gap_start <= k.last_closed_day::TIMESTAMP
        AND g.gap_end >= (k.last_closed_day + 1)::TIMESTAMP
ORDER BY g.slug, g.gap_start;
