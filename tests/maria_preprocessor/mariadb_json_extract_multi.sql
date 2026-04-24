SELECT `ID`, JSON_EXTRACT(`JSON`, '$.a', '$.b') AS `both` FROM `json_test` ORDER BY `ID`
