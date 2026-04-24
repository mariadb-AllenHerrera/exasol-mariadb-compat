SELECT "ID", UTIL.JSON_EXTRACT("JSON", '["$.a", "$.b"]') AS "both"
FROM json_test
ORDER BY "ID"
