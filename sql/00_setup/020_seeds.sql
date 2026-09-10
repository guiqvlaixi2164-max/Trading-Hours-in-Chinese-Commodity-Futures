-- Hand-made reference tables from seeds/*.csv, with explicit column types.
-- Clock times are kept as TIME and as minutes after midnight (*_min), which is what the bar
-- tables use (stg.bars.clock_min).

CREATE OR REPLACE TABLE seed.contracts AS
SELECT
    slug,
    code,
    exchange,
    name_en,
    name_cn,
    sector,
    raw_file,
    linkage,
    linkage_reason
FROM read_csv(
    'seeds/contracts.csv',
    header = TRUE,
    columns = {
        'slug': 'VARCHAR',
        'code': 'VARCHAR',
        'exchange': 'VARCHAR',
        'name_en': 'VARCHAR',
        'name_cn': 'VARCHAR',
        'sector': 'VARCHAR',
        'raw_file': 'VARCHAR',
        'linkage': 'VARCHAR',
        'linkage_reason': 'VARCHAR'
    }
);

CREATE OR REPLACE TABLE seed.session_blocks AS
SELECT
    block,
    clock_start::TIME AS clock_start,
    clock_end::TIME AS clock_end,
    last_stamp::TIME AS last_stamp,
    hour(clock_start::TIME) * 60 + minute(clock_start::TIME) AS start_min,
    hour(clock_end::TIME) * 60 + minute(clock_end::TIME) AS end_min,
    hour(last_stamp::TIME) * 60 + minute(last_stamp::TIME) AS last_stamp_min,
    block_order
FROM read_csv(
    'seeds/session_blocks.csv',
    header = TRUE,
    columns = {
        'block': 'VARCHAR',
        'clock_start': 'VARCHAR',
        'clock_end': 'VARCHAR',
        'last_stamp': 'VARCHAR',
        'block_order': 'INTEGER'
    }
);

-- The companion pipeline's fixed night window per contract, used only by the compatibility rule
-- set (Phase 3). Day-only contracts have no night window.
CREATE OR REPLACE TABLE seed.compat_night_windows AS
SELECT
    slug,
    session_template,
    night_start::TIME AS night_start,
    night_last_stamp::TIME AS night_last_stamp,
    hour(night_start::TIME) * 60 + minute(night_start::TIME) AS night_start_min,
    hour(night_last_stamp::TIME) * 60 + minute(night_last_stamp::TIME) AS night_last_stamp_min
FROM read_csv(
    'seeds/compat_night_windows.csv',
    header = TRUE,
    columns = {
        'slug': 'VARCHAR',
        'session_template': 'VARCHAR',
        'night_start': 'VARCHAR',
        'night_last_stamp': 'VARCHAR'
    }
);

-- days_of_week: ISO weekday numbers (Monday = 1) of the US Eastern date.
-- applies_to: ['all'] or a list of slugs.
CREATE OR REPLACE TABLE seed.us_scheduled_events AS
SELECT
    event,
    et_time::TIME AS et_time,
    hour(et_time::TIME) * 60 + minute(et_time::TIME) AS et_min,
    string_split(days_of_week, '|')::INTEGER[] AS days_of_week,
    string_split(applies_to, '|') AS applies_to,
    description
FROM read_csv(
    'seeds/us_scheduled_events.csv',
    header = TRUE,
    columns = {
        'event': 'VARCHAR',
        'et_time': 'VARCHAR',
        'days_of_week': 'VARCHAR',
        'applies_to': 'VARCHAR',
        'description': 'VARCHAR'
    }
);
