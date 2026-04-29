CREATE OR REPLACE PYTHON3 SCALAR SCRIPT UTIL.GET_GLOT_VERSION()
RETURNS VARCHAR(64) AS

# Returns the sqlglot version string visible to the active SCRIPT_LANGUAGES
# SLC. Lets tests confirm they're hitting the SLC they expect — some preprocessor
# rewrites (e.g. USE -> OPEN SCHEMA from sqlglot PR #7538) only work on SLCs
# whose bundled sqlglot is recent enough.

import sqlglot


def run(ctx):
    return getattr(sqlglot, "__version__", "unknown")
