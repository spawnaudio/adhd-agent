"""Run the imported agent for the Mac app, with private local session storage."""
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
import uvicorn


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    if not 1024 <= port <= 65535:
        raise ValueError("Use a local port between 1024 and 65535")
    os.umask(0o077)
    directory = Path(os.environ.get(
        "FOCUS_FLOW_DATA_DIR",
        str(Path.home() / "Library/Application Support/FocusFlow/companion"),
    ))
    directory.mkdir(parents=True, exist_ok=True)
    load_dotenv(directory / ".env")
    load_dotenv(Path(__file__).parent / ".env")
    from google.adk.cli.service_registry import get_service_registry
    from google.adk.sessions.sqlite_session_service import SqliteSessionService
    get_service_registry().register_session_service(
        "focusflow", lambda uri, **kwargs: SqliteSessionService(str(directory / "sessions.db"))
    )
    os.environ.setdefault("SESSION_SERVICE_URI", "focusflow://session")
    os.environ.setdefault("APP_URL", f"http://127.0.0.1:{port}")
    from app.fast_api_app import app
    uvicorn.run(app, host="127.0.0.1", port=port)


if __name__ == "__main__":
    main()
