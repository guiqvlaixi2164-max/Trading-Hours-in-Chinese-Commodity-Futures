-- Step 3a, each contract's own trading calendar: the calendar dates on which it has day-session
-- bars, per rule set. Night bars are later mapped onto this calendar.
CREATE OR REPLACE TABLE clean.contract_calendar AS
SELECT DISTINCT
    rule_set,
    slug,
    cal_date AS trading_date
FROM clean.bars_block
WHERE block <> 'night';
