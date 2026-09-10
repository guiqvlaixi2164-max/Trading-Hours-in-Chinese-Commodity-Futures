-- Step 2a, the block windows each contract's bars are assigned to, under two rule sets:
--   session_aware  one envelope for every contract (seed.session_blocks); the night block is
--                  21:00 to 03:00, so every night bar the exchange printed is kept. Default.
--   compat         the companion's fixed template per contract (seed.compat_night_windows);
--                  day blocks as above, night limited to the template's window.
-- Both rule sets are carried through the clean layer. `--compat` only chooses which one feeds
-- clean.bars and everything downstream; this is the only difference between the two modes.
-- A window whose last stamp is earlier than its start crosses midnight.
CREATE OR REPLACE TABLE clean.block_rules AS
SELECT
    'session_aware' AS rule_set,
    c.slug,
    b.block,
    b.block_order,
    b.start_min,
    b.last_stamp_min
FROM seed.contracts AS c
CROSS JOIN seed.session_blocks AS b

UNION ALL

SELECT
    'compat' AS rule_set,
    c.slug,
    b.block,
    b.block_order,
    CASE WHEN b.block = 'night' THEN w.night_start_min ELSE b.start_min END AS start_min,
    CASE WHEN b.block = 'night' THEN w.night_last_stamp_min ELSE b.last_stamp_min END
        AS last_stamp_min
FROM seed.contracts AS c
CROSS JOIN seed.session_blocks AS b
INNER JOIN seed.compat_night_windows AS w ON c.slug = w.slug
WHERE b.block <> 'night' OR w.night_start_min IS NOT NULL;
