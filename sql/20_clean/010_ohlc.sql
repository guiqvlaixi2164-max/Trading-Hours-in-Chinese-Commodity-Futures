-- Step 1, OHLC sanity: positive volume, low <= high, open and close within [low, high], and a
-- positive close.
CREATE OR REPLACE VIEW clean.bars_ohlc AS
SELECT *
FROM stg.bars
WHERE
    volume > 0
    AND low <= high
    AND open BETWEEN low AND high
    AND close BETWEEN low AND high
    AND close > 0;
