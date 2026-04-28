CREATE OR REPLACE PYTHON3 PREPROCESSOR SCRIPT UTIL.MARIA_PREPROCESSOR AS

# Transparent MariaDB -> Exasol query rewriter (production / "safe" variant).
#
# sqlglot (inside the current SLC) parses the incoming MariaDB SQL into an
# AST. We walk it and rewrite specific constructs into UTIL.* calls (or into
# native Exasol functions) that preserve MariaDB semantics. Any failure in
# parse/transform/generate returns the original statement unchanged so Exasol
# gets a chance to execute it natively — better a database-level error than a
# preprocessor-level crash, and Exasol-only syntax (OPEN SCHEMA, MINUS, etc.)
# sails through.
#
# For loud-failure dev iteration, swap to UTIL.MARIA_PREPROCESSOR_DEBUG:
#   ALTER SESSION SET sql_preprocessor_script=UTIL.MARIA_PREPROCESSOR_DEBUG;
#
# Rewrites below must stay byte-identical to the debug variant; only
# adapter_call differs. Keep them in sync.

import json
import sqlglot
from sqlglot import exp


def adapter_call(request):
    try:
        return _transpile(request)
    except Exception:
        return request


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

    if (isinstance(node, exp.Anonymous)
            and isinstance(node.this, str)
            and node.this.upper() == "JSON_UNQUOTE"):
        # sqlglot.transform does not recurse into a replaced node's children,
        # so apply _rewrite to inner args here — otherwise JSON_UNQUOTE(JSON_EXTRACT(...))
        # would leave the inner JSON_EXTRACT untransformed and unresolvable on Exasol.
        new_exprs = [e.transform(_rewrite_to_util) if isinstance(e, exp.Expression) else e
                     for e in node.expressions]
        return exp.Anonymous(this="UTIL.JSON_UNQUOTE", expressions=new_exprs)

    if (isinstance(node, exp.Anonymous)
            and isinstance(node.this, str)
            and node.this.upper() in ("JSON_MERGE_PRESERVE", "JSON_MERGE")):
        # JSON_MERGE is the deprecated MariaDB alias of JSON_MERGE_PRESERVE.
        # Same recursion concern as JSON_UNQUOTE above — descend into args
        # so e.g. JSON_MERGE_PRESERVE(JSON_EXTRACT(doc, '$.a'), ...) still rewrites.
        new_exprs = [e.transform(_rewrite_to_util) if isinstance(e, exp.Expression) else e
                     for e in node.expressions]
        return exp.Anonymous(this="UTIL.JSON_MERGE_PRESERVE", expressions=new_exprs)

    if (isinstance(node, exp.Anonymous)
            and isinstance(node.this, str)
            and node.this.upper() == "ELT"):
        # The SLC's bundled sqlglot (currently 27.6.0) parses ELT as Anonymous —
        # this branch is what fires today. Same recursion rule as JSON_UNQUOTE.
        new_exprs = [e.transform(_rewrite_to_util) if isinstance(e, exp.Expression) else e
                     for e in node.expressions]
        return exp.Anonymous(this="UTIL.ELT", expressions=new_exprs)

    # Newer sqlglot exposes a typed exp.Elt node (this=N, expressions=[strs...]).
    # Guarded with getattr so the preprocessor doesn't crash on the older SLC.
    _Elt = getattr(exp, "Elt", None)
    if _Elt is not None and isinstance(node, _Elt):
        args = [node.this, *node.expressions]
        new_args = [a.transform(_rewrite_to_util) if isinstance(a, exp.Expression) else a
                    for a in args]
        return exp.Anonymous(this="UTIL.ELT", expressions=new_args)

    return node


def _strip_sql_quotes(rendered):
    if len(rendered) >= 2 and rendered[0] == "'" and rendered[-1] == "'":
        return rendered[1:-1].replace("''", "'")
    return rendered
