#!/bin/sh
set -eu
PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
printf 'Starting the included Focus & Flow companion at http://127.0.0.1:8000
Press Control-C to stop.
'
exec /bin/sh "${FOCUS_FLOW_AGENT_DIR:-$PROJECT_DIR/companion}/start.sh" "${FOCUS_FLOW_AGENT_PORT:-8000}"
