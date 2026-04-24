#!/usr/bin/env python3
"""Install the UTIL.* MariaDB-compat UDFs into an Exasol database.

Scans udfs/**/*.sql recursively and runs each as a single CREATE OR REPLACE.
Idempotent — safe to re-run to update existing UDFs.

Install: pip install pyexasol
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    import pyexasol
except ImportError:
    sys.stderr.write("pyexasol is required: pip install pyexasol\n")
    sys.exit(3)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--host", default="localhost")
    p.add_argument("--port", default="8563")
    p.add_argument("--user", default="sys")
    p.add_argument("--password", default="exasol")
    p.add_argument("--no-ssl-verify", action="store_true",
                   help="Skip Exasol TLS cert validation (for docker-db's self-signed cert)")
    p.add_argument("--udfs-dir", type=Path, default=Path(__file__).parent / "udfs",
                   help="Root directory to scan for *.sql files (default: ./udfs)")
    args = p.parse_args()

    sql_files = sorted(args.udfs_dir.rglob("*.sql"))
    if not sql_files:
        print(f"[warn] no .sql files found under {args.udfs_dir}", file=sys.stderr)
        return 0

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
        c.execute("CREATE SCHEMA IF NOT EXISTS UTIL")
    except Exception as e:
        print(f"[setup] CREATE SCHEMA UTIL failed: {e}", file=sys.stderr)
        return 3

    root = args.udfs_dir.resolve()
    for f in sql_files:
        rel = f.resolve().relative_to(root)
        stmt = f.read_text().strip().rstrip(";")
        try:
            c.execute(stmt)
            print(f"[ok] installed {rel}")
        except Exception as e:
            print(f"[fail] {rel}: {e}", file=sys.stderr)
            return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
