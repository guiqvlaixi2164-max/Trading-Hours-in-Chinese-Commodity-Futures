-- The typed load produced no NULL or NaN fields and every stamp sits on the five-minute grid.
-- Checked clean on 2026-09-10; this guards against a changed raw file.
SELECT
    slug,
    ts,
    open,
    high,
    low,
    close,
    volume,
    position
FROM stg.bars
WHERE
    ts IS NULL
    OR open IS NULL OR high IS NULL OR low IS NULL OR close IS NULL
    OR volume IS NULL OR position IS NULL
    OR isnan(open) OR isnan(high) OR isnan(low) OR isnan(close)
    OR second(ts) <> 0 OR minute(ts) % 5 <> 0;
