-- Step 8, dead days: trading days whose sum of squared (repaired) returns is zero. They are
-- removed from clean.bars; returns and gap returns are not recomputed afterwards, as in the
-- companion, so a gap return may span a removed day.
CREATE OR REPLACE TABLE clean.days_dead AS
SELECT
    rule_set,
    slug,
    trading_day
FROM clean.bars_flagged
GROUP BY rule_set, slug, trading_day
HAVING sum(ret * ret) = 0;
