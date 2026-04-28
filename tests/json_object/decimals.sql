SELECT JSON_OBJECT(
    'int_decimal',  CAST(42 AS DECIMAL(10, 0)),
    'frac_decimal', CAST(3.14 AS DECIMAL(5, 2))
)
