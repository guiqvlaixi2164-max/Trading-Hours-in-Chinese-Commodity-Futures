-- Five-minute slots of the trading day, from the night open (slot_key 0 = 21:00) to the last
-- day-session stamp (slot_key 1075 = 14:55). slot_order is the sort key for the label, so that
-- 21:00 sorts before 09:00. Slots outside every block (for example 03:00-08:55) are off_session.
CREATE OR REPLACE TABLE core.dim_slot AS
WITH last_stamp AS (
    SELECT slot_key(arg_max(last_stamp_min, block_order)) AS last_key
    FROM seed.session_blocks
),

slots AS (
    SELECT
        unnest(range(0, l.last_key + getvariable('bar_minutes'), getvariable('bar_minutes')))
            AS slot_key
    FROM last_stamp AS l
),

n AS (
    SELECT start_min
    FROM seed.session_blocks
    WHERE block = 'night'
),

clock AS (
    SELECT
        s.slot_key,
        (s.slot_key + n.start_min) % 1440 AS clock_min
    FROM slots AS s
    CROSS JOIN n
)

SELECT
    c.slot_key::INTEGER AS slot_key,
    c.slot_key::INTEGER AS slot_order,
    c.clock_min::INTEGER AS clock_min,
    left((TIME '00:00' + to_minutes(c.clock_min::INTEGER))::VARCHAR, 5) AS label,
    coalesce(b.block, 'off_session') AS block,
    b.block_order,
    b.block IS NOT NULL AS is_in_session
FROM clock AS c
LEFT JOIN seed.session_blocks AS b
    ON
        (b.start_min <= b.last_stamp_min AND c.clock_min BETWEEN b.start_min AND b.last_stamp_min)
        OR (
            b.start_min > b.last_stamp_min
            AND (c.clock_min >= b.start_min OR c.clock_min <= b.last_stamp_min)
        )
ORDER BY c.slot_key;
