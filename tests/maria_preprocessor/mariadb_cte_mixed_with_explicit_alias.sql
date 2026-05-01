WITH t AS (
    SELECT 'foo' AS keep, 42, 1 + 2
)
SELECT * FROM t
