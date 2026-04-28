CREATE OR REPLACE PYTHON3 SCALAR SCRIPT UTIL.JSON_MERGE_PRESERVE(...)
RETURNS VARCHAR(2000000) AS

import json

# MariaDB JSON_MERGE_PRESERVE semantics:
#   - Requires >= 2 args.
#   - Any NULL arg -> NULL.
#   - Adjacent objects: union by key; if a key collides, values are combined
#     (recursively merged: two objects -> nested merge; everything else -> autowrap
#     each side to an array and concatenate).
#   - Adjacent arrays: concatenate.
#   - Mixed object/array or scalars: autowrap each side to an array and concatenate.
# JSON_MERGE is a deprecated MariaDB alias and shares the same semantics; the
# preprocessor maps both names to this UDF.
# Invalid JSON in any arg -> NULL (MariaDB raises; we return NULL conservatively
# rather than aborting the whole statement).

_MISS = object()


def _parse(s):
    try:
        return json.loads(s)
    except (ValueError, TypeError):
        return _MISS


def _merge(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(a)
        for k, v in b.items():
            out[k] = _merge(out[k], v) if k in out else v
        return out
    if isinstance(a, list) and isinstance(b, list):
        return a + b
    a_list = a if isinstance(a, list) else [a]
    b_list = b if isinstance(b, list) else [b]
    return a_list + b_list


def run(ctx):
    n = exa.meta.input_column_count
    if n < 2:
        raise ValueError('JSON_MERGE_PRESERVE requires at least 2 arguments')
    vals = []
    for i in range(n):
        s = ctx[i]
        if s is None:
            return None
        v = _parse(s)
        if v is _MISS:
            return None
        vals.append(v)
    result = vals[0]
    for nxt in vals[1:]:
        result = _merge(result, nxt)
    return json.dumps(result, ensure_ascii=False)
