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

| UDF | MariaDB function | Notes |
|---|---|---|
| `UTIL.JSON_EXTRACT(doc, paths_json_array)` | `JSON_EXTRACT(doc, p1, ..., pN)` | Single path → JSON-typed value; multi-path → JSON array of matches with missing paths silently skipped; all-missing → NULL. Path grammar: `$`, `$.key`, `$[idx]`, dotted/indexed chains. Wildcards (`$**`, `$[*]`) not yet supported. |
| `UTIL.JSON_OBJECT(k1, v1, ..., kN, vN)` | `JSON_OBJECT(k1, v1, ...)` | Variadic key/value pairs → JSON object. DECIMAL values render as integers or floats; DATE / TIMESTAMP render as ISO-8601 strings. Odd-arg or NULL-key calls raise. |

## Adding or updating UDFs (build from source)

1. Drop a single `CREATE OR REPLACE PYTHON3 SCALAR SCRIPT UTIL.<name>(...) ...`
   into `udfs/<category>/<name>.sql`. No trailing `;` or `/`.
2. Run `./build.sh` to regenerate `dist/mariadb-compat.sql` (stamped with the
   current `git describe` version).
3. Commit both the UDF source and the updated `dist/` file.

## Layout

```
exasol-mariadb-compat/
├── install.py                  # pyexasol installer (idempotent)
├── build.sh                    # aggregates udfs/**/*.sql → dist/mariadb-compat.sql
├── udfs/
│   └── json/
│       └── json_extract.sql    # one CREATE OR REPLACE per file
├── dist/
│   └── mariadb-compat.sql      # built artifact, committed
└── tests/
    └── fixtures/
```

## Versioning

The first line of `dist/mariadb-compat.sql` carries the version, filled in by
`build.sh` from `git describe`. Tag releases (`v0.1.0`, `v0.2.0`, …) when you
cut one.
