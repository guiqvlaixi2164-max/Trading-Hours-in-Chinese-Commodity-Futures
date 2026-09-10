-- seed.contracts: unique slugs and raw files, known exchanges and linkage classes, and the
-- pre-registered linkage counts (docs/HYPOTHESES.md §7: 17 / 8 / 9).
SELECT
    'duplicate slug' AS problem,
    slug AS item
FROM seed.contracts
GROUP BY slug
HAVING count(*) > 1

UNION ALL

SELECT
    'duplicate raw_file' AS problem,
    raw_file AS item
FROM seed.contracts
GROUP BY raw_file
HAVING count(*) > 1

UNION ALL

SELECT
    'unknown exchange' AS problem,
    slug AS item
FROM seed.contracts
WHERE exchange NOT IN ('SHFE', 'INE', 'DCE', 'CZCE')

UNION ALL

SELECT
    'unknown linkage' AS problem,
    slug AS item
FROM seed.contracts
WHERE linkage NOT IN ('international', 'partial', 'domestic')

UNION ALL

SELECT
    'linkage count changed' AS problem,
    linkage || '=' || count(*) AS item
FROM seed.contracts
GROUP BY linkage
HAVING
    count(*) <> CASE linkage
        WHEN 'international' THEN 17
        WHEN 'partial' THEN 8
        WHEN 'domestic' THEN 9
    END;
