CREATE OR REPLACE PYTHON3 SCALAR SCRIPT UTIL.ELT(...)
RETURNS VARCHAR(2000000) AS

# MariaDB ELT(N, str1[, str2, ...]) semantics:
#   - 1-based pick: ELT(1, 'a', 'b', 'c') -> 'a', ELT(2, ...) -> 'b'.
#   - N is NULL          -> NULL.
#   - N < 1 or N > count -> NULL.
#   - Selected element itself NULL -> NULL.
#   - Fractional N is truncated toward zero (ELT(2.7, 'a', 'b', 'c') -> 'b').
#   - Non-numeric N (e.g. an arbitrary string) -> NULL conservatively.
# Requires at least 2 args (one index + one string); fewer raises (matches MariaDB syntax).


def run(ctx):
    n_args = exa.meta.input_column_count
    if n_args < 2:
        raise ValueError('ELT requires at least 2 arguments (index and one string)')
    raw = ctx[0]
    if raw is None:
        return None
    try:
        n = int(float(raw))
    except (ValueError, TypeError):
        return None
    string_count = n_args - 1
    if n < 1 or n > string_count:
        return None
    val = ctx[n]
    return None if val is None else str(val)
