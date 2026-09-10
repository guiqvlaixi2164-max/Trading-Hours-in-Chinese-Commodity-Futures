-- One row per contract, trading day and block present that day: first open, last close, bar
-- span, volume and within-block realised variance. The building block for segments, daily
-- facts, gaps and the session history.
CREATE OR REPLACE TABLE core.day_blocks AS
SELECT
    slug,
    trading_day,
    block,
    any_value(block_order) AS block_order,
    count(*) AS n_bars,
    min(ts) AS first_ts,
    max(ts) AS last_ts,
    arg_min(open, seq) AS first_open,
    arg_max(close, seq) AS last_close,
    slot_key(arg_min(clock_min, seq)) AS first_slot_key,
    slot_key(arg_max(clock_min, seq)) AS last_slot_key,
    sum(volume) AS volume,
    coalesce(sum(ret * ret), 0) AS rv
FROM clean.bars
GROUP BY slug, trading_day, block
ORDER BY slug, trading_day, block_order;
