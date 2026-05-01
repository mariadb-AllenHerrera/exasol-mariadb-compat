#!/usr/bin/env bash
# Wrapper that compiles Runner.java on first run, then exec's it with the
# Connector/J + org.json jars on the classpath. run_tests.py invokes this
# the same way it invokes node/python runners — args after this script are
# passed to Runner.
set -euo pipefail
cd "$(dirname "$0")"

CP="lib/*"
if [ ! -f Runner.class ] || [ Runner.java -nt Runner.class ]; then
    javac -cp "$CP" Runner.java >&2
fi

exec java -cp ".:$CP" Runner "$@"
