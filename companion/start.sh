#!/bin/sh
set -eu
SOURCE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DATA_DIR="${FOCUS_FLOW_DATA_DIR:-$HOME/Library/Application Support/FocusFlow/companion}"
UV_BIN="${UV_BIN:-$HOME/.local/bin/uv}"
if [ ! -x "$UV_BIN" ]; then
  UV_BIN="$(command -v uv || true)"
fi
if [ ! -x "$UV_BIN" ]; then
  printf 'Install uv to run the companion: https://docs.astral.sh/uv/
' >&2
  exit 1
fi
umask 077
mkdir -p "$DATA_DIR"
export FOCUS_FLOW_DATA_DIR="$DATA_DIR"
export UV_PROJECT_ENVIRONMENT="$DATA_DIR/.venv"
export PYTHONDONTWRITEBYTECODE=1
"$UV_BIN" sync --frozen --no-dev --project "$SOURCE_DIR"
cd "$DATA_DIR"
exec "$UV_BIN" run --no-sync --project "$SOURCE_DIR" python -B "$SOURCE_DIR/native_server.py" "${1:-8000}"
