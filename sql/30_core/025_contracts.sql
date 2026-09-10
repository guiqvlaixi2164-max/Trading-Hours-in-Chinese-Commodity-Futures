-- One row per contract: exchange group and cleaned date range. INE shares SHFE's trading
-- calendar and is grouped with it.
CREATE OR REPLACE TABLE core.contracts AS
SELECT
    c.slug,
    c.exchange,
    CASE WHEN c.exchange = 'INE' THEN 'SHFE' ELSE c.exchange END AS exchange_group,
    min(d.trading_day) AS first_trading_day,
    max(d.trading_day) AS last_trading_day,
    count(*) AS n_trading_days
FROM seed.contracts AS c
INNER JOIN clean.days AS d ON c.slug = d.slug
GROUP BY c.slug, c.exchange
ORDER BY c.slug;
