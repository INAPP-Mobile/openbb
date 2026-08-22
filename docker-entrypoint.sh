#!/bin/sh
# OpenBB Platform API entrypoint.
# Single source of truth for the listen port is Railway's PORT:
# the app's own OPENBB_API_PORT is derived from it (unless explicitly set).
set -e

export OPENBB_API_HOST="${OPENBB_API_HOST:-0.0.0.0}"
if [ -n "${PORT:-}" ]; then
    export OPENBB_API_PORT="${PORT}"
fi
export OPENBB_API_PORT="${OPENBB_API_PORT:-6900}"

echo "[openbb] OpenBB Platform API on ${OPENBB_API_HOST}:${OPENBB_API_PORT} (docs: /docs, spec: /openapi.json)"
exec openbb-api --host "${OPENBB_API_HOST}" --port "${OPENBB_API_PORT}"
