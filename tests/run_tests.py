#!/usr/bin/env python3
"""Run UDF regression tests against a running Exasol with UTIL.* installed.

Each subdirectory of tests/ is one UDF group. Inside, optionally a setup.sql
of fixtures, then one `<name>.sql` + `<name>.expected.json` pair per test case.
The SQL file holds a single SELECT; the JSON file holds the expected rows as
a list of lists. Rows are compared stringified so DECIMAL/int/float collapse.

Prereqs: UTIL.* UDFs installed (run ../install.py first).

Install: pip install pyexasol
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    import pyexasol
except ImportError:
    sys.stderr.write("pyexasol is required: pip install pyexasol\n")
    sys.exit(3)


def _split_sql(text: str) -> list[str]:
    return [s.strip() for s in text.split(";") if s.strip()]


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--host", default="localhost")
    p.add_argument("--port", default="8563")
    p.add_argument("--user", default="sys")
    p.add_argument("--password", default="exasol")
    p.add_argument("--no-ssl-verify", action="store_true",
                   help="Skip Exasol TLS cert validation (for docker-db's self-signed cert)")
    p.add_argument("--tests-dir", type=Path, default=Path(__file__).parent,
                   help="Directory to scan for UDF test subdirs (default: this script's dir)")
    p.add_argument("--schema", default="MARIADB_COMPAT_TEST",
                   help="Ephemeral schema for fixtures (dropped at end)")
    p.add_argument("--udf", action="append", default=None,
                   help="Run only these UDF groups (repeatable; default: all)")
    args = p.parse_args()

    connect_kwargs = dict(dsn=f"{args.host}:{args.port}", user=args.user,
                          password=args.password, compression=True)
    if args.no_ssl_verify:
        import ssl
        connect_kwargs["websocket_sslopt"] = {"cert_reqs": ssl.CERT_NONE}

    try:
        c = pyexasol.connect(**connect_kwargs)
    except Exception as e:
        print(f"[setup] connection failed: {e}", file=sys.stderr)
        return 3

    try:
        c.execute(f"CREATE SCHEMA IF NOT EXISTS {args.schema}")
        c.execute(f"OPEN SCHEMA {args.schema}")
    except Exception as e:
        print(f"[setup] schema creation failed: {e}", file=sys.stderr)
        return 3

    udf_dirs = sorted(d for d in args.tests_dir.iterdir()
                      if d.is_dir() and d.name not in ("__pycache__", "fixtures"))
    if args.udf:
        udf_dirs = [d for d in udf_dirs if d.name in args.udf]

    passed = failed = 0
    for udf_dir in udf_dirs:
        setup = udf_dir / "setup.sql"
        if setup.exists():
            try:
                for stmt in _split_sql(setup.read_text()):
                    c.execute(stmt)
            except Exception as e:
                print(f"[FAIL] {udf_dir.name}/setup: {e}", file=sys.stderr)
                failed += 1
                continue

        cases = sorted(f for f in udf_dir.glob("*.sql") if f.name != "setup.sql")
        for sql_file in cases:
            name = sql_file.stem
            expected_file = sql_file.with_suffix(".expected.json")
            if not expected_file.exists():
                print(f"[skip] {udf_dir.name}/{name}: no .expected.json")
                continue
            label = f"{udf_dir.name}/{name}"
            try:
                rows = [list(r) for r in c.execute(sql_file.read_text()).fetchall()]
                expected = json.loads(expected_file.read_text())
            except Exception as e:
                print(f"[FAIL] {label}: {e}", file=sys.stderr)
                failed += 1
                continue

            if [[str(x) for x in r] for r in rows] == [[str(x) for x in r] for r in expected]:
                print(f"[ok]   {label}")
                passed += 1
            else:
                print(f"[FAIL] {label}", file=sys.stderr)
                print(f"       expected: {expected}", file=sys.stderr)
                print(f"       actual  : {rows}", file=sys.stderr)
                failed += 1

    try:
        c.execute(f"DROP SCHEMA {args.schema} CASCADE")
    except Exception:
        pass

    total = passed + failed
    print(f"\n{passed}/{total} passed" + (f", {failed} failed" if failed else ""))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
