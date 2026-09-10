-- The eight return segments (seed.segments), for the segment dimension in Power BI.
CREATE OR REPLACE TABLE core.dim_segment AS
SELECT
    segment,
    segment_group,
    segment_order,
    description
FROM seed.segments
ORDER BY segment_order;
