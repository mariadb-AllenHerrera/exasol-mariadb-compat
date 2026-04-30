WITH outer_cte AS (
    WITH inner_cte AS (SELECT 999)
    SELECT 'x' FROM inner_cte
)
SELECT * FROM outer_cte
