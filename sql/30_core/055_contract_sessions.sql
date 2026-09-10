-- Night-session adoption per contract: the first trading day with at least
-- `min_night_bars_first_day` night bars. A contract whose adoption comes within
-- `listed_with_night_max_pre_days` trading days of its first day was listed with a night session
-- (the listing day itself has no evening before it). Day-only contracts have no adoption day.
CREATE OR REPLACE TABLE core.contract_sessions AS
WITH adoption AS (
    SELECT
        slug,
        min(trading_day) AS adoption_day
    FROM core.day_blocks
    WHERE block = 'night' AND n_bars >= getvariable('min_night_bars_first_day')
    GROUP BY slug
),

pre AS (
    SELECT
        a.slug,
        count(d.trading_day) AS pre_adoption_days
    FROM adoption AS a
    LEFT JOIN clean.days AS d ON a.slug = d.slug AND a.adoption_day > d.trading_day
    GROUP BY a.slug
)

SELECT
    c.slug,
    c.exchange_group,
    c.first_trading_day,
    c.last_trading_day,
    a.adoption_day,
    p.pre_adoption_days,
    a.adoption_day IS NOT NULL AS has_night_session,
    coalesce(p.pre_adoption_days <= getvariable('listed_with_night_max_pre_days'), FALSE)
        AS is_listed_with_night
FROM core.contracts AS c
LEFT JOIN adoption AS a ON c.slug = a.slug
LEFT JOIN pre AS p ON c.slug = p.slug
ORDER BY c.slug;
