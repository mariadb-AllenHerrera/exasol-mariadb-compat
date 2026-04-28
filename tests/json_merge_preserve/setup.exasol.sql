DROP TABLE IF EXISTS json_merge_test;

CREATE TABLE json_merge_test (
    "ID"   INT,
    "A"    VARCHAR(2000000),
    "B"    VARCHAR(2000000),
    PRIMARY KEY ("ID")
);

INSERT INTO json_merge_test VALUES
    (1, '{"a": 1, "b": 2}', '{"c": 3, "d": 4}'),
    (2, '{"a": 1, "b": 2}', '{"a": 9, "c": 3}'),
    (3, '[1, 2]',           '[3, 4]'),
    (4, '{"x": 1}',          NULL);

ALTER SESSION SET sql_preprocessor_script=UTIL.MARIA_PREPROCESSOR;
