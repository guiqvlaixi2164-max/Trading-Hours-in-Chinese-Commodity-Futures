-- Raw five-minute bars, typed and tagged with the contract slug. Nothing is removed.
-- Timestamps are Beijing wall-clock time, left-stamped (the 21:20 bar covers 21:20-21:25).
-- Rows are stored in (slug, ts) order so that later window functions and zone maps benefit.
CREATE OR REPLACE TABLE stg.bars AS
SELECT
    c.slug,
    r.datetime AS ts,
    r.datetime::DATE AS cal_date,
    hour(r.datetime) * 60 + minute(r.datetime) AS clock_min,
    r.open,
    r.high,
    r.low,
    r.close,
    r.volume,
    r.position
FROM
    read_csv(
        'data/raw/*.csv',
        filename = true,
        header = true,
        columns = {
            'datetime': 'TIMESTAMP',
            'open': 'DOUBLE',
            'high': 'DOUBLE',
            'low': 'DOUBLE',
            'close': 'DOUBLE',
            'volume': 'DOUBLE',
            'position': 'DOUBLE'
        }
    ) AS r
INNER JOIN seed.contracts AS c
    ON c.raw_file = regexp_extract(r.filename, '[^/\\]+$')
ORDER BY c.slug, r.datetime;
