CREATE OR REPLACE PYTHON3 SCALAR SCRIPT UTIL.JSON_OBJECT(...)
RETURNS VARCHAR(2000000) AS

import json
import decimal
import datetime


def default_serializer(obj):
    if isinstance(obj, decimal.Decimal):
        if obj == obj.to_integral_value():
            return int(obj)
        return float(obj)
    if isinstance(obj, datetime.datetime):
        return obj.isoformat()
    if isinstance(obj, datetime.date):
        return obj.isoformat()
    raise TypeError(f'Object of type {type(obj).__name__} is not JSON serializable')


def run(ctx):
    n = exa.meta.input_column_count
    if n % 2 != 0:
        raise ValueError('JSON_OBJECT requires an even number of arguments (key-value pairs)')
    obj = {}
    for i in range(0, n, 2):
        key = ctx[i]
        if key is None:
            raise ValueError('JSON_OBJECT key must not be NULL')
        key = str(key)
        value = ctx[i + 1]
        obj[key] = value
    return json.dumps(obj, default=default_serializer, ensure_ascii=False)
