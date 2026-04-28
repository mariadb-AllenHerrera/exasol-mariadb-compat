CREATE OR REPLACE PYTHON3 PREPROCESSOR SCRIPT UTIL.MARIA_PREPROCESSOR_DEBUG AS

# DEBUG variant of UTIL.MARIA_PREPROCESSOR — same rewrite rules, but errors
# raise instead of falling back to the original statement. Use during
# development to surface sqlglot ParseErrors and transform bugs as immediate
# query failures with full tracebacks.
#
# Toggle:
#   ALTER SESSION SET sql_preprocessor_script=UTIL.MARIA_PREPROCESSOR_DEBUG;
#
# Switch back for production:
#   ALTER SESSION SET sql_preprocessor_script=UTIL.MARIA_PREPROCESSOR;
#
# The rewrite logic below MUST stay byte-identical to the safe variant; only
# adapter_call differs. If you change rules in one, change them in the other.

import json
import sqlglot
from sqlglot import exp


def adapter_call(request):
    return _transpile(request)


def _transpile(request):
    tree = sqlglot.parse_one(request, read="mysql")
    if tree is None:
        return request
    tree = tree.transform(_rewrite_to_util)
    return tree.sql(dialect="exasol", identify=True)


def _rewrite_to_util(node):
    if isinstance(node, exp.JSONExtract) and not node.args.get("emits"):
        paths = []
        if node.expression is not None:
            paths.append(_strip_sql_quotes(node.expression.sql()))
        paths.extend(_strip_sql_quotes(p.sql()) for p in node.expressions)
        return exp.Anonymous(
            this="UTIL.JSON_EXTRACT",
            expressions=[node.this, exp.Literal.string(json.dumps(paths))],
        )

    if isinstance(node, exp.JSONObject):
        args = []
        for kv in node.expressions:
            args.append(kv.this)
            args.append(kv.expression)
        return exp.Anonymous(this="UTIL.JSON_OBJECT", expressions=args)

    return node


def _strip_sql_quotes(rendered):
    if len(rendered) >= 2 and rendered[0] == "'" and rendered[-1] == "'":
        return rendered[1:-1].replace("''", "'")
    return rendered
