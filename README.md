# exasol-mariadb-compat

MariaDB-compatible SQL UDFs for Exasol. Pairs with a MariaDB→Exasol query
rewriter (e.g. a sqlglot-based preprocessor) so apps written against MariaDB
run unchanged against Exasol.

All UDFs live in `UTIL.*` and are `CREATE OR REPLACE` — the same command
installs fresh and updates.

## Quick start

Pick whichever matches your tooling. Both install the committed
`dist/mariadb-compat.sql`, which is regenerated on every merge to `main`.

### exaplus (or any client that honours the `/` delimiter)

```sh
curl -sSL -o mariadb-compat.sql \
    https://raw.githubusercontent.com/mariadb-AllenHerrera/exasol-mariadb-compat/main/dist/mariadb-compat.sql

exaplus -c <host>:8563 -u sys -p <pw> -f mariadb-compat.sql
```

### Python (pyexasol)

```sh
git clone https://github.com/mariadb-AllenHerrera/exasol-mariadb-compat.git
cd exasol-mariadb-compat

pip install pyexasol
python install.py --host <host> --user sys --password <pw> [--no-ssl-verify]
```

Re-run either command any time to pick up new/updated UDFs.

## What's shipped today

### UDFs (`udfs/`)

| UDF | MariaDB function | Notes |
|---|---|---|
| `UTIL.JSON_EXTRACT(doc, paths_json_array)` | `JSON_EXTRACT(doc, p1, ..., pN)` | Single path → JSON-typed value; multi-path → JSON array of matches with missing paths silently skipped; all-missing → NULL. Path grammar: `$`, `$.key`, `$[idx]`, dotted/indexed chains. Wildcards (`$**`, `$[*]`) not yet supported. |
| `UTIL.JSON_OBJECT(k1, v1, ..., kN, vN)` | `JSON_OBJECT(k1, v1, ...)` | Variadic key/value pairs → JSON object. DECIMAL values render as integers or floats; DATE / TIMESTAMP render as ISO-8601 strings. Odd-arg or NULL-key calls raise. |

### Preprocessor (`preprocessor/`)

`UTIL.MARIA_PREPROCESSOR` is an Exasol preprocessor script that, when
activated with `ALTER SESSION SET sql_preprocessor_script=UTIL.MARIA_PREPROCESSOR`,
transparently rewrites MariaDB SQL into Exasol SQL before it reaches the
engine. Under the hood it uses `sqlglot` (from whatever SLC is active) to
parse MariaDB, walks the AST rewriting specific constructs into calls
against the UDFs above (or into native Exasol functions where they match),
then generates the final Exasol SQL.

The rewrite table lives inside the preprocessor script. When adding a new
UDF here, add a corresponding branch to `_rewrite_to_util` in
`preprocessor/maria_preprocessor.sql` in the same PR. Currently covered:

- `JSON_EXTRACT` / `->` → `UTIL.JSON_EXTRACT`
- `->>` → `JSON_VALUE` (native Exasol)
- `JSON_OBJECT` → `UTIL.JSON_OBJECT`

## Adding or updating UDFs (build from source)

1. Drop a single `CREATE OR REPLACE PYTHON3 SCALAR SCRIPT UTIL.<name>(...) ...`
   into `udfs/<category>/<name>.sql`. No trailing `;` or `/`.
2. Run `./build.sh` to regenerate `dist/mariadb-compat.sql` (stamped with the
   current `git describe` version).
3. Commit both the UDF source and the updated `dist/` file.

## Testing

Each UDF has a directory under `tests/` with optional `setup.sql` fixtures
plus `<case>.sql` + `<case>.expected.json` pairs. Rows are compared
stringified so `DECIMAL` / `int` / `float` collapse.

```sh
# Prereq: UTIL.* already installed (see Quick start)
pip install pyexasol
python tests/run_tests.py --host <host> --user sys --password <pw> [--no-ssl-verify]

# Only one UDF:
python tests/run_tests.py --udf json_object --no-ssl-verify
```

The runner creates an ephemeral `MARIADB_COMPAT_TEST` schema, runs each
group's `setup.sql` inside it, executes every case, then `DROP SCHEMA ...
CASCADE`s. No persistent state.

## Layout

```
exasol-mariadb-compat/
├── install.py                  # pyexasol installer (idempotent)
├── build.sh                    # aggregates udfs/**/*.sql → dist/mariadb-compat.sql
├── udfs/
│   └── json/
│       ├── json_extract.sql    # one CREATE OR REPLACE per file
│       └── json_object.sql
├── preprocessor/
│   └── maria_preprocessor.sql  # UTIL.MARIA_PREPROCESSOR: AST-level MariaDB → Exasol rewriter
├── dist/
│   └── mariadb-compat.sql      # built artifact, committed
└── tests/
    ├── run_tests.py
    ├── json_extract/           # UDF runtime tests (raw UTIL.* calls)
    ├── json_object/
    └── maria_preprocessor/     # end-to-end MariaDB SQL through the preprocessor
```

## Versioning

The first line of `dist/mariadb-compat.sql` carries the version, filled in by
`build.sh` from `git describe`. Tag releases (`v0.1.0`, `v0.2.0`, …) when you
cut one.
