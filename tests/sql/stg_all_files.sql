-- All 34 contracts are staged, and every raw CSV maps to a seeded contract. A raw file with no
-- seed row would be dropped silently by the join in 010_stg_bars.sql.
SELECT
    'seeded contract not staged' AS problem,
    c.slug AS item
FROM seed.contracts AS c
WHERE c.slug NOT IN (SELECT DISTINCT b.slug FROM stg.bars AS b)

UNION ALL

SELECT
    'raw file without seed row' AS problem,
    regexp_extract(g.file, '[^/\\]+$') AS item
FROM glob('data/raw/*.csv') AS g
WHERE regexp_extract(g.file, '[^/\\]+$') NOT IN (SELECT c.raw_file FROM seed.contracts AS c)

UNION ALL

SELECT
    'expected 34 contracts' AS problem,
    count(*)::VARCHAR AS item
FROM seed.contracts
HAVING count(*) <> 34;
