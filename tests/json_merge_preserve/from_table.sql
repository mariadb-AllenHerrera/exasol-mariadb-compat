SELECT `ID`, JSON_MERGE_PRESERVE(`A`, `B`) AS merged
FROM `json_merge_test`
ORDER BY `ID`
