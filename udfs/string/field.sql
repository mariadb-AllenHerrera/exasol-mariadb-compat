CREATE OR REPLACE PYTHON3 SCALAR SCRIPT UTIL.FIELD(...)
RETURNS INT AS

# MariaDB FIELD(str, str1[, str2, ...]) semantics:
#   - 1-based search: returns the index of `str` in the list, or 0 if not found.
#   - str is NULL          -> 0 (NULL never equals NULL, so it's never "found").
#   - List element NULL    -> skipped, never matches.
#   - All args numeric     -> numeric comparison.
#   - Otherwise            -> case-sensitive string comparison. MariaDB's
#     "convert mixed args to double" rule is intentionally NOT replicated:
#     it silently coerces non-numeric strings to 0 and produces surprising
#     matches (e.g. FIELD('x', 0, 'y') -> 1). String compare is safer here.
#   - Only `str` provided (no list) -> 0.
# FIELD is the complement of ELT.

import decimal


def run(ctx):
    n_args = exa.meta.input_column_count
    if n_args < 1:
        raise ValueError('FIELD requires at least 1 argument (the search value)')
    needle = ctx[0]
    if needle is None:
        return 0
    if n_args == 1:
        return 0

    vals = [ctx[i] for i in range(1, n_args)]

    numeric = (isinstance(needle, (int, float, decimal.Decimal))
               and all(v is None or isinstance(v, (int, float, decimal.Decimal))
                       for v in vals))

    if numeric:
        n = float(needle)
        for i, v in enumerate(vals, start=1):
            if v is None:
                continue
            if float(v) == n:
                return i
        return 0

    s = str(needle)
    for i, v in enumerate(vals, start=1):
        if v is None:
            continue
        if str(v) == s:
            return i
    return 0
