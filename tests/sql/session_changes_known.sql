-- The session history finds the changes in PROJECT_PLAN.md §2 (plan Phase 4, step 1 test):
--   adoptions   the 18 treated contracts' first night-session days (§2.1)
--   suspension  every contract with a night session in January 2020 is suspended from
--               2020-02-03 (2020-02-04 where its 3 February is missing), and nothing else is
--   night end   exactly these shortenings, and no extension (§2.3; slot keys: 325 = 02:25,
--               235 = 00:55, 145 = 23:25, 115 = 22:55 last stamp)
WITH expected_adoption (slug, trading_day) AS (
    VALUES
    ('gold', DATE '2013-07-08'), ('silver', DATE '2013-07-08'),
    ('copper', DATE '2013-12-23'), ('aluminium', DATE '2013-12-23'), ('zinc', DATE '2013-12-23'),
    ('coke', DATE '2014-07-07'),
    ('methanol', DATE '2014-12-15'), ('sugar', DATE '2014-12-15'),
    ('soybean_oil', DATE '2014-12-29'), ('soybean_meal', DATE '2014-12-29'),
    ('rubber', DATE '2014-12-29'), ('rebar', DATE '2014-12-29'),
    ('iron_ore', DATE '2014-12-29'), ('coking_coal', DATE '2014-12-29'),
    ('bitumen', DATE '2015-01-06'),
    ('polypropylene', DATE '2019-04-01'), ('pvc', DATE '2019-04-01'),
    ('corn_starch', DATE '2019-04-01')
),

expected_end_change (slug, change_type, trading_day, from_end_key, to_end_key) AS (
    VALUES
    ('coke', 'shortening', DATE '2015-05-11', 325, 145),
    ('coking_coal', 'shortening', DATE '2015-05-11', 325, 145),
    ('iron_ore', 'shortening', DATE '2015-05-11', 325, 145),
    ('soybean_meal', 'shortening', DATE '2015-05-11', 325, 145),
    ('soybean_oil', 'shortening', DATE '2015-05-11', 325, 145),
    ('rebar', 'shortening', DATE '2016-05-04', 235, 115),
    ('bitumen', 'shortening', DATE '2016-05-04', 235, 115),
    ('coke', 'shortening', DATE '2019-04-01', 145, 115),
    ('coking_coal', 'shortening', DATE '2019-04-01', 145, 115),
    ('iron_ore', 'shortening', DATE '2019-04-01', 145, 115),
    ('soybean_meal', 'shortening', DATE '2019-04-01', 145, 115),
    ('soybean_oil', 'shortening', DATE '2019-04-01', 145, 115),
    ('soybean_2', 'shortening', DATE '2019-04-01', 145, 115),
    ('sugar', 'shortening', DATE '2019-12-12', 145, 115),
    ('methanol', 'shortening', DATE '2019-12-12', 145, 115)
),

actual_end_change AS (
    SELECT
        slug,
        change_type,
        trading_day,
        from_end_key,
        to_end_key
    FROM core.session_changes
    WHERE change_type IN ('shortening', 'extension')
),

night_in_january_2020 AS (
    SELECT DISTINCT slug
    FROM core.fct_day
    WHERE has_night_block AND trading_day BETWEEN DATE '2020-01-01' AND DATE '2020-01-31'
),

suspensions AS (
    SELECT
        slug,
        trading_day
    FROM core.session_changes
    WHERE change_type = 'suspension'
)

SELECT
    'adoption missing or on another day' AS problem,
    e.slug,
    e.trading_day
FROM expected_adoption AS e
ANTI JOIN core.session_changes AS s
    ON e.slug = s.slug AND s.change_type = 'adoption' AND e.trading_day = s.trading_day

UNION ALL

SELECT
    'expected night-end change missing' AS problem,
    x.slug,
    x.trading_day
FROM (
    SELECT * FROM expected_end_change
    EXCEPT
    SELECT * FROM actual_end_change
) AS x

UNION ALL

SELECT
    'unexpected night-end change' AS problem,
    x.slug,
    x.trading_day
FROM (
    SELECT * FROM actual_end_change
    EXCEPT
    SELECT * FROM expected_end_change
) AS x

UNION ALL

SELECT
    'no 2020 suspension' AS problem,
    n.slug,
    NULL AS trading_day
FROM night_in_january_2020 AS n
ANTI JOIN suspensions AS s
    ON n.slug = s.slug AND s.trading_day BETWEEN DATE '2020-02-03' AND DATE '2020-02-04'

UNION ALL

SELECT
    'unexpected suspension' AS problem,
    s.slug,
    s.trading_day
FROM suspensions AS s
WHERE
    s.trading_day NOT BETWEEN DATE '2020-02-03' AND DATE '2020-02-04'
    OR s.slug NOT IN (SELECT n.slug FROM night_in_january_2020 AS n);
