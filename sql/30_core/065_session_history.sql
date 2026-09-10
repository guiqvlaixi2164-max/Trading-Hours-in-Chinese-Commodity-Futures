-- Night session per contract and calendar month (plan Phase 4, step 1; the Power BI session
-- heatmap). Start and end are slot keys (minutes after 21:00) of the first and last night bar;
-- the end is the month's most frequent daily end (ties to the later end), the start the earliest.
-- night_minutes spans the first night bar's open to the modal last bar's close.
CREATE OR REPLACE TABLE core.session_history AS
WITH days AS (
    SELECT
        d.slug,
        date_trunc('month', d.trading_day)::DATE AS month,
        n.n_bars AS n_night_bars,
        n.first_slot_key,
        n.last_slot_key
    FROM clean.days AS d
    LEFT JOIN core.day_blocks AS n
        ON d.slug = n.slug AND d.trading_day = n.trading_day AND n.block = 'night'
),

end_counts AS (
    SELECT
        slug,
        month,
        last_slot_key,
        count(*) AS n
    FROM days
    WHERE last_slot_key IS NOT NULL
    GROUP BY slug, month, last_slot_key
),

modal_end AS (
    SELECT
        slug,
        month,
        last_slot_key AS night_end_key
    FROM end_counts
    QUALIFY
        row_number() OVER (PARTITION BY slug, month ORDER BY n DESC, last_slot_key DESC) = 1
),

monthly AS (
    SELECT
        slug,
        month,
        count(*) AS n_days,
        count(n_night_bars) AS n_night_days,
        coalesce(sum(n_night_bars), 0) AS n_night_bars,
        min(first_slot_key) AS night_start_key
    FROM days
    GROUP BY slug, month
)

SELECT
    m.slug,
    m.month,
    m.n_days,
    m.n_night_days,
    m.n_night_bars,
    m.night_start_key,
    e.night_end_key,
    m.n_night_days > 0 AS has_night,
    coalesce(e.night_end_key + getvariable('bar_minutes') - m.night_start_key, 0) AS night_minutes
FROM monthly AS m
LEFT JOIN modal_end AS e ON m.slug = e.slug AND m.month = e.month
ORDER BY m.slug, m.month;
