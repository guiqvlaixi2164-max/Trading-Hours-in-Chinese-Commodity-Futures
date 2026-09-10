-- Trading-day assignment on known cases (plan Phase 3, step 3). Returns every case whose bar is
-- missing or maps to the wrong trading day.
--   Friday 21:00 gold bar                        -> the following Monday
--   Saturday 00:30 gold bar                      -> the following Monday
--   Thursday 21:15 tin bar before a day with no  -> the next day with a day session (Monday).
--   tin day session (2015-09-11: night bars only)   No night bar precedes an exchange closure of
--                                                   4+ days (the session is always cancelled),
--                                                   so this is the gap case that exists.
WITH expected (slug, ts, trading_day) AS (
    VALUES
    ('gold', TIMESTAMP '2016-01-08 21:00:00', DATE '2016-01-11'),
    ('gold', TIMESTAMP '2016-01-09 00:30:00', DATE '2016-01-11'),
    ('tin', TIMESTAMP '2015-09-10 21:15:00', DATE '2015-09-14')
)

SELECT
    e.slug,
    e.ts,
    e.trading_day AS expected_trading_day,
    b.trading_day AS actual_trading_day
FROM expected AS e
LEFT JOIN clean.bars_day AS b
    ON e.slug = b.slug AND e.ts = b.ts
WHERE b.trading_day IS DISTINCT FROM e.trading_day;
