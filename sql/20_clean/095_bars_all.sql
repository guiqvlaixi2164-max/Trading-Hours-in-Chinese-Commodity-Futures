-- Cleaned bars of both rule sets (dead days removed), for the waterfall, the departure table and
-- the reconciliation tests. clean.bars holds the active rule set only.
CREATE OR REPLACE VIEW clean.bars_all AS
SELECT f.* EXCLUDE (f.med, f.mad, f.global_mad, f.threshold)
FROM clean.bars_flagged AS f
ANTI JOIN clean.days_dead AS d
    ON f.rule_set = d.rule_set AND f.slug = d.slug AND f.trading_day = d.trading_day;
