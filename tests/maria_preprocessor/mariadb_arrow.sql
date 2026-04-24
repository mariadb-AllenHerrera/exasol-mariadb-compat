SELECT `ID`, `JSON` -> '$.a' AS a_json, `JSON` ->> '$.a' AS a_text FROM `json_test` ORDER BY `ID`
