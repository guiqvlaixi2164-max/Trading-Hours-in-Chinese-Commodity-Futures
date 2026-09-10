-- US and UK summer time in core.dim_date (from the ICU time-zone data) agree with the statutory
-- rules on every date (plan Phase 4, step 7):
--   US from 2007   second Sunday of March to first Sunday of November
--   US to 2006     first Sunday of April to last Sunday of October
--   UK             last Sunday of March to last Sunday of October
-- A date counts as summer time from the switch Sunday itself (the switch is at night, and
-- dim_date evaluates noon).
WITH months AS (
    SELECT
        year,
        make_date(year, 3, 1) AS mar1,
        make_date(year, 4, 1) AS apr1,
        make_date(year, 11, 1) AS nov1,
        last_day(make_date(year, 3, 1)) AS mar_end,
        last_day(make_date(year, 10, 1)) AS oct_end
    FROM (SELECT DISTINCT year FROM core.dim_date) AS years
),

rules AS (
    SELECT
        year,
        CASE
            WHEN year >= 2007 THEN mar1 + ((7 - isodow(mar1)) % 7 + 7)::INTEGER
            ELSE apr1 + ((7 - isodow(apr1)) % 7)::INTEGER
        END AS us_start,
        CASE
            WHEN year >= 2007 THEN nov1 + ((7 - isodow(nov1)) % 7)::INTEGER
            ELSE oct_end - (isodow(oct_end) % 7)::INTEGER
        END AS us_end,
        mar_end - (isodow(mar_end) % 7)::INTEGER AS uk_start,
        oct_end - (isodow(oct_end) % 7)::INTEGER AS uk_end
    FROM months
)

SELECT
    d.date,
    d.us_dst,
    d.date >= r.us_start AND d.date < r.us_end AS us_rule,
    d.uk_bst,
    d.date >= r.uk_start AND d.date < r.uk_end AS uk_rule
FROM core.dim_date AS d
INNER JOIN rules AS r ON d.year = r.year
WHERE
    d.us_dst <> (d.date >= r.us_start AND d.date < r.us_end)
    OR d.uk_bst <> (d.date >= r.uk_start AND d.date < r.uk_end);
