-- Step 2b, block assignment: each bar is joined to the block whose window contains its clock
-- stamp, once per rule set. Bars inside no window are off-session and drop out here.
CREATE OR REPLACE VIEW clean.bars_block AS
SELECT
    r.rule_set,
    b.*,
    r.block,
    r.block_order
FROM clean.bars_ohlc AS b
INNER JOIN clean.block_rules AS r
    ON
        b.slug = r.slug
        AND (
            (
                r.start_min <= r.last_stamp_min
                AND b.clock_min BETWEEN r.start_min AND r.last_stamp_min
            )
            OR (
                r.start_min > r.last_stamp_min
                AND (b.clock_min >= r.start_min OR b.clock_min <= r.last_stamp_min)
            )
        );
