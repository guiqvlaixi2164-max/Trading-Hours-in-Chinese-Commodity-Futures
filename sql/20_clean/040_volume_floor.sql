-- Step 4, thin days: a trading day whose total volume is below the contract's
-- `daily_volume_percentile_floor` quantile of daily volume is flagged for removal.
-- quantile_cont interpolates linearly, as pandas' default Series.quantile does.
CREATE OR REPLACE TABLE clean.day_volume AS
WITH daily AS (
    SELECT
        rule_set,
        slug,
        trading_day,
        count(*) AS n_bars,
        sum(volume) AS day_volume
    FROM clean.bars_day
    GROUP BY rule_set, slug, trading_day
),

floors AS (
    SELECT
        rule_set,
        slug,
        quantile_cont(day_volume, getvariable('daily_volume_percentile_floor')) AS volume_floor
    FROM daily
    GROUP BY rule_set, slug
)

SELECT
    d.rule_set,
    d.slug,
    d.trading_day,
    d.n_bars,
    d.day_volume,
    f.volume_floor,
    d.day_volume < f.volume_floor AS is_below_floor
FROM daily AS d
INNER JOIN floors AS f ON d.rule_set = f.rule_set AND d.slug = f.slug;
