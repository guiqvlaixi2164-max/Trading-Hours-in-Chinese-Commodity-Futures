-- slot_key: minutes after the night open (21:00) of a clock time given in minutes after midnight,
-- so the trading day runs 0 (21:00) ... 1075 (14:55) and midnight crossing needs no special case.
-- 1440 is minutes per day, not a parameter; the night open comes from seed.session_blocks.
CREATE OR REPLACE MACRO slot_key(clock_min) AS (
    clock_min - (
        SELECT sb.start_min FROM seed.session_blocks AS sb
        WHERE sb.block = 'night'
    ) + 1440
) % 1440;
