-- Step 5, short days: of the days that pass the volume floor, keep those with at least
-- `min_bars_per_day` bars. The result is the list of days that enter the return calculation.
CREATE OR REPLACE TABLE clean.days_kept AS
SELECT
    rule_set,
    slug,
    trading_day
FROM clean.day_volume
WHERE NOT is_below_floor AND n_bars >= getvariable('min_bars_per_day');
