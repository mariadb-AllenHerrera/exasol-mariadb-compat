SELECT `ID`, ELT(`IDX`, `S1`, `S2`, `S3`) AS picked
FROM `elt_test`
ORDER BY `ID`
