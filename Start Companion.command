#!/bin/zsh
set -euo pipefail
COMPANION_DIR="${FOCUS_FLOW_AGENT_DIR:-/Users/squeakyvermin/Developer/Google Enterprise/Agents/focus-flow-companion}"
UV_BIN="${commands[uv]:-$HOME/.local/bin/uv}"
if [[ ! -f "$COMPANION_DIR/app/agent.py" || ! -x "$UV_BIN" ]]; then
  printf 'The existing companion or uv was not found. See docs/GETTING_STARTED.md.\n'
  exit 1
fi
cd "$COMPANION_DIR"
export PYTHONDONTWRITEBYTECODE=1
export UV_CACHE_DIR="${TMPDIR:-/tmp}/focus-flow-uv-cache"
printf 'Starting your existing companion at http://127.0.0.1:8000\nKeep this window open while using agent suggestions. Press Control-C to stop.\n'
exec "$UV_BIN" run --no-sync python -B -m uvicorn app.fast_api_app:app --host 127.0.0.1 --port 8000
