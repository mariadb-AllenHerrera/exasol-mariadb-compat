SELECT CONCAT(category, '_', status) AS hash_key, COUNT(*) AS cnt
FROM (
    SELECT 'a' AS category, 'active'   AS status
    UNION ALL SELECT 'a' AS category, 'active'   AS status
    UNION ALL SELECT 'b' AS category, 'reserved' AS status
) AS t
GROUP BY hash_key
ORDER BY hash_key
