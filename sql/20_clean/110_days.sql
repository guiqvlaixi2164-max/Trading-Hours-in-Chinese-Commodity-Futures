-- The cleaned contract-days of the active rule set, with their flags.
CREATE OR REPLACE TABLE clean.days AS
SELECT * EXCLUDE (rule_set)
FROM clean.days_all
WHERE rule_set = CASE WHEN getvariable('compat_mode') THEN 'compat' ELSE 'session_aware' END
ORDER BY slug, trading_day;
