"""pymysql JSON Lines runner.

Same driver-mode protocol as tests/connectors/nodejs/runner.js. See
tests/connectors/README.md.

Note for the MaxScale / ExasolRouter team reading this as a repro:
pymysql is pure Python and does NOT auto-issue `SET NAMES` at handshake
(it negotiates charset in the binary auth packet). So unlike libmariadb,
connection succeeds. But explicit `SET NAMES utf8mb4` issued by user code
goes over the wire as SQL, hits exasolrouter -> Exasol JDBC -> early
SET-variable dispatch -> "Lost connection during query" because the JDBC
layer rejects it without surfacing a clean error.
"""
import argparse
import json
import sys

import pymysql


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def normalize(v):
    if v is None:
        return None
    if isinstance(v, (bytes, bytearray)):
        # MaxScale's ExasolRouter serializes actual SQL NULL as the literal
        # 4-byte ASCII string "NULL" instead of the MariaDB-protocol NULL
        # marker. None of the test fixture columns hold the literal word
        # "NULL" as a value, so map back to None.
        if bytes(v) == b"NULL":
            return None
        return v.decode("utf-8", errors="replace")
    if isinstance(v, (int, float, bool, str)):
        return v
    return str(v)  # Decimal, datetime, etc.


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=3309)
    p.add_argument("--user", default="admin_user")
    p.add_argument("--password", default="")
    args = p.parse_args()

    try:
        conn = pymysql.connect(
            host=args.host, port=args.port,
            user=args.user, password=args.password,
            autocommit=True, connect_timeout=5,
        )
    except Exception as e:
        emit({"event": "error", "error": f"{type(e).__name__}: {e}"})
        sys.exit(2)

    emit({"event": "ready", "driver": f"pymysql@{pymysql.__version__}"})

    cur = conn.cursor()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception as e:
            emit({"name": "?", "ok": False, "error": f"bad json: {e}"})
            continue
        try:
            cur.execute(req["sql"])
            # pymysql.fetchall() returns () for non-SELECT, doesn't raise.
            rows = [[normalize(v) for v in r] for r in (cur.fetchall() or ())]
            emit({"name": req["name"], "ok": True, "rows": rows})
        except Exception as e:
            emit({"name": req["name"], "ok": False, "error": f"{type(e).__name__}: {e}"})

    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
