CREATE OR REPLACE PYTHON3 PREPROCESSOR SCRIPT UTIL.MARIA_PREPROCESSOR AS

# Transparent MariaDB -> Exasol query rewriter.
#
# sqlglot (inside the current SLC) transpiles the incoming MariaDB SQL into
# the most faithful native-Exasol form it can. For MariaDB constructs whose
# semantics have no native Exasol equivalent (lossy or absent), we rewrite
# those specific AST nodes to calls into the UTIL.* helper UDF pack shipped
# alongside this script. Both halves are required; one without the other is
# either broken (transpile produces unsupported SQL) or unreachable (UDFs
# installed but never called).
#
# Rewrites below must stay in sync with udfs/**/*.sql. Anything shipped as
# UTIL.<name> should have a matching branch in _rewrite_to_util.

import json
import sqlglot
from sqlglot import exp


def adapter_call(request):
    tree = sqlglot.parse_one(request, read="mysql")
    tree = tree.transform(_rewrite_to_util)
    return tree.sql(dialect="exasol", identify=True)


def _rewrite_to_util(node):
    # MariaDB scalar JSON_EXTRACT / -> -> UTIL.JSON_EXTRACT (JSON-typed output,
    # multi-path returns an array, missing paths silently skipped).
    if isinstance(node, exp.JSONExtract) and not node.args.get("emits"):
        paths = []
        if node.expression is not None:
            paths.append(_strip_sql_quotes(node.expression.sql()))
        paths.extend(_strip_sql_quotes(p.sql()) for p in node.expressions)
        return exp.Anonymous(
            this="UTIL.JSON_EXTRACT",
            expressions=[node.this, exp.Literal.string(json.dumps(paths))],
        )

    # MariaDB ->> (JSON_UNQUOTE(JSON_EXTRACT(...))) -> Exasol JSON_VALUE, a
    # faithful match for scalar extraction. Emitted here so the rewrite doesn't
    # depend on the active SLC's sqlglot version shipping an Exasol-dialect
    # override for JSONExtractScalar.
    if isinstance(node, exp.JSONExtractScalar):
        return exp.Anonymous(
            this="JSON_VALUE",
            expressions=[node.this, node.expression],
        )

    # MariaDB JSON_OBJECT(k, v, k, v, ...) -> UTIL.JSON_OBJECT(variadic).
    # Exasol has no native JSON_OBJECT.
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
