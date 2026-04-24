CREATE OR REPLACE PYTHON3 SCALAR SCRIPT UTIL.JSON_EXTRACT(
    doc   VARCHAR(2000000),
    paths VARCHAR(2000000)
) RETURNS VARCHAR(2000000) AS
import json
import re

# MariaDB JSON_EXTRACT semantics:
#   - one path  -> that match as JSON text (strings quoted, numbers bare,
#                  objects/arrays preserved)
#   - multi     -> JSON array of found values, missing paths silently skipped
#   - all miss  -> NULL
# Path grammar: "$", "$.key", "$[idx]", combinations. Wildcards are not supported;
# unsupported paths behave as "missing" (conservative -- MariaDB would error).
_TOKEN = re.compile(r"\.([A-Za-z_][A-Za-z_0-9]*)|\[(\d+)\]")
_UNSUPPORTED = re.compile(r"\*\*|\[\*\]|\?|\(")
_MISS = object()


def _resolve(node, path):
    if not isinstance(path, str) or not path.startswith("$"):
        return _MISS
    rest = path[1:]
    if _UNSUPPORTED.search(rest):
        return _MISS
    i = 0
    cur = node
    while i < len(rest):
        m = _TOKEN.match(rest, i)
        if not m:
            return _MISS
        key, idx = m.groups()
        if key is not None:
            if not isinstance(cur, dict) or key not in cur:
                return _MISS
            cur = cur[key]
        else:
            j = int(idx)
            if not isinstance(cur, list) or j >= len(cur):
                return _MISS
            cur = cur[j]
        i = m.end()
    return cur


def run(ctx):
    if ctx.doc is None or ctx.paths is None:
        return None
    try:
        data = json.loads(ctx.doc)
    except (ValueError, TypeError):
        return None
    try:
        path_list = json.loads(ctx.paths)
    except (ValueError, TypeError):
        return None
    if not isinstance(path_list, list):
        path_list = [path_list]
    found = []
    for p in path_list:
        v = _resolve(data, p)
        if v is not _MISS:
            found.append(v)
    if not found:
        return None
    if len(path_list) == 1:
        return json.dumps(found[0])
    return json.dumps(found)
