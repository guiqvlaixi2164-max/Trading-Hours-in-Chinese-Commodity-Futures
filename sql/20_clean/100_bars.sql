-- The cleaned bars that everything downstream reads: the active rule set (session_aware by
-- default, compat with `--compat`).
CREATE OR REPLACE TABLE clean.bars AS
SELECT * EXCLUDE (rule_set)
FROM clean.bars_all
WHERE rule_set = CASE WHEN getvariable('compat_mode') THEN 'compat' ELSE 'session_aware' END
ORDER BY slug, seq;
