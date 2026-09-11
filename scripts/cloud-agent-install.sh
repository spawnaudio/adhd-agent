#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for Focus & Flow.
# Designed for a dual-host workflow:
#   - macOS My Machines workers: full SwiftPM tests / native tooling
#   - Linux cloud VMs: toolchain + packaging checks only (no SwiftUI/AppKit)
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" ]]; then
  # shellcheck disable=SC1090,SC1091
  . "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
fi

OS="$(uname -s)"
case "$OS" in
  Darwin)
    if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app ]]; then
      export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
    fi
    if ! command -v xcrun >/dev/null 2>&1; then
      echo "xcrun not found. Install full Xcode on this Mac worker." >&2
      exit 1
    fi
    xcrun swift --version
    xcrun swift test
    ;;
  Linux)
    if ! command -v swift >/dev/null 2>&1; then
      echo "swift not found on PATH. Install Swift via Swiftly into the base snapshot." >&2
      exit 1
    fi
    swift --version
    echo "Linux host: skipping native app build/tests (SwiftUI/AppKit + Apple Foundation APIs)."
    echo "Use a macOS My Machines worker for xcrun swift test and scripts/build-app.sh."
    ;;
  *)
    echo "Unsupported OS for this environment: $OS" >&2
    exit 1
    ;;
esac

sh -n scripts/build-app.sh

python3 - <<'PY'
from pathlib import Path
import plistlib

root = Path("packaging")
paths = sorted(root.glob("*.plist"))
if not paths:
    raise SystemExit("No packaging/*.plist files found")
for path in paths:
    with path.open("rb") as handle:
        plistlib.load(handle)
    print(f"plist ok: {path}")
PY

if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout packaging/*.plist
fi

echo "cloud-agent-install: ok"
