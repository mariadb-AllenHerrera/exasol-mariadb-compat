#!/usr/bin/env bash
# Fetch Connector/J + org.json into ./lib so Runner.java compiles.
# run.sh checks for the jars and re-compiles Runner.java when stale.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p lib
MJC_VERSION=3.5.6
JSON_VERSION=20250517
[ -f "lib/mariadb-java-client-${MJC_VERSION}.jar" ] || \
    curl -fsSL -o "lib/mariadb-java-client-${MJC_VERSION}.jar" \
        "https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/${MJC_VERSION}/mariadb-java-client-${MJC_VERSION}.jar"
[ -f "lib/json-${JSON_VERSION}.jar" ] || \
    curl -fsSL -o "lib/json-${JSON_VERSION}.jar" \
        "https://repo1.maven.org/maven2/org/json/json/${JSON_VERSION}/json-${JSON_VERSION}.jar"
echo "lib/ ready:"
ls -1 lib/*.jar
