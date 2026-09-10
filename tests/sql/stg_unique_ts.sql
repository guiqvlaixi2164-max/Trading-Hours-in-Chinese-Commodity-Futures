-- No duplicate (slug, ts) in stg.bars.
SELECT
    slug,
    ts,
    count(*) AS n
FROM stg.bars
GROUP BY slug, ts
HAVING count(*) > 1;
