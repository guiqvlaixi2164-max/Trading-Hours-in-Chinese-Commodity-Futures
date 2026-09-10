-- Step 6, returns on the kept days, in the companion's definitions:
--   seq      position in the contract's bar sequence (night block first within a trading day);
--   ret      log close-to-close return within (trading day, block); NULL on each block's first bar;
--   gap_ret  log return from the previous bar's close, kept only where ret is NULL. It spans
--            breaks, overnight gaps and any day removed in steps 4 and 5.
CREATE OR REPLACE VIEW clean.bars_returns AS
WITH kept AS (
    SELECT b.*
    FROM clean.bars_day AS b
    SEMI JOIN clean.days_kept AS k
        ON b.rule_set = k.rule_set AND b.slug = k.slug AND b.trading_day = k.trading_day
),

returns AS (
    SELECT
        *,
        row_number() OVER w_seq AS seq,
        ln(close) - lag(ln(close)) OVER (
            PARTITION BY rule_set, slug, trading_day, block ORDER BY ts
        ) AS ret,
        ln(close) - lag(ln(close)) OVER w_seq AS any_ret
    FROM kept
    WINDOW w_seq AS (PARTITION BY rule_set, slug ORDER BY trading_day, block_order, ts)
)

SELECT
    * EXCLUDE (any_ret),
    CASE WHEN ret IS NULL THEN any_ret END AS gap_ret
FROM returns;
