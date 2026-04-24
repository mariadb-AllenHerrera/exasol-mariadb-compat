SELECT `ID`, JSON_EXTRACT(`JSON`, '$.a') AS a FROM `json_test` ORDER BY `ID`
