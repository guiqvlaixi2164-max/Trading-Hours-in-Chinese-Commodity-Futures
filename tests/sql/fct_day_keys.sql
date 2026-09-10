-- core.fct_day has exactly one row per cleaned contract-day.
SELECT
    coalesce(f.slug, d.slug) AS slug,
    coalesce(f.trading_day, d.trading_day) AS trading_day,
    count(*) AS n
FROM core.fct_day AS f
FULL OUTER JOIN clean.days AS d ON f.slug = d.slug AND f.trading_day = d.trading_day
GROUP BY coalesce(f.slug, d.slug), coalesce(f.trading_day, d.trading_day)
HAVING count(*) <> 1 OR count(f.slug) = 0 OR count(d.slug) = 0;
