# exasol-mariadb-compat

SQL UDFs that give Exasol MariaDB-compatible behavior for functions Exasol
doesn't have natively (or whose semantics differ). Designed to pair with a
MariaDB→Exasol query rewriter (e.g. a sqlglot-based preprocessor) so that
applications written against MariaDB run unchanged against Exasol.

All UDFs live in the `UTIL` schema and use `CREATE OR REPLACE` — installing
an update is the same command as installing fresh.

## Install

Two ways, pick whichever fits your tooling.

### exaplus / any client that speaks `@file.sql`

```sh
exaplus -c <host>:8563 -u <user> -p <pass> -f dist/mariadb-compat.sql
```

`dist/mariadb-compat.sql` is a committed, auto-generated aggregate of every
UDF in `udfs/**/*.sql`. Pull it down directly if you don't want the repo:

```sh
curl -O https://raw.githubusercontent.com/<you>/exasol-mariadb-compat/main/dist/mariadb-compat.sql
```

### Python (pyexasol)

```sh
pip install pyexasol
python install.py --host localhost --user sys --password <pw>
# Add --no-ssl-verify for docker-db's self-signed cert.
```

Idempotent. Re-run after `git pull` to pick up updated UDFs.

## What's shipped today

| UDF | MariaDB function | Notes |
|---|---|---|
| `UTIL.JSON_EXTRACT(doc, paths_json_array)` | `JSON_EXTRACT(doc, p1, ..., pN)` | Single-path returns JSON-typed value, multi-path returns JSON array, missing paths silently skipped, all-missing returns NULL. Path grammar: `$`, `$.key`, `$[idx]`, dotted/indexed chains. Wildcards (`$**`, `$[*]`) not yet supported — return NULL. |

## Adding a new UDF

1. Drop a single `CREATE OR REPLACE PYTHON3 SCALAR SCRIPT UTIL.<name>(...) ...`
   file into `udfs/<category>/<name>.sql`. No trailing `;` or `/`.
2. Run `./build.sh` to regenerate `dist/mariadb-compat.sql`.
3. Add a test fixture under `tests/fixtures/` and an e2e case if the
   semantics are non-trivial.
4. Commit both the UDF source and the regenerated `dist/` file.

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
