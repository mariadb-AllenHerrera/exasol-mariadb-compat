CREATE OR REPLACE PYTHON3 SCALAR SCRIPT UTIL.JSON_UNQUOTE(
    val VARCHAR(2000000)
) RETURNS VARCHAR(2000000) AS
import json

# MariaDB JSON_UNQUOTE semantics (lenient variant; MySQL is stricter):
#   NULL                 -> NULL
#   '"hello"'            -> 'hello'             (JSON string -> unescaped text)
#   '"a\\nb"'            -> 'a' + LF + 'b'      (JSON escapes resolved)
#   anything else        -> input unchanged     (numbers, objects, arrays,
#                                                already-unquoted text, garbage)
# A value counts as a JSON string only if it parses to a Python str. Objects
# and arrays pass through verbatim, matching MariaDB's behavior.


def run(ctx):
    s = ctx.val
    if s is None:
        return None
    if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
        try:
            v = json.loads(s)
        except ValueError:
            return s
        if isinstance(v, str):
            return v
    return s
