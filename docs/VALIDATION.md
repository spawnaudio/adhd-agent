# Prototype validation — 5 September 2026

## Passed

- Native debug and release builds using the installed Xcode beta toolchain on Apple Silicon / macOS 27 beta.
- Local `.app` packaging and ad-hoc signature verification for Focus & Flow.
- **18 Focus & Flow tests:** raw capture preservation, three-priority limit, focus input validation, pause/resume accounting, pause expiry after a simulated sleep/relaunch, duplicate step completion prevention, Linear URL validation, JSON round-trip including unfinished editor text, file permissions, corrupt/newer-version handling, final agent text extraction, connection detection, HTTP failures, and temporary-session cleanup.
- **4 existing Focus tests:** retained and passed after restoring the earlier app's targets to the shared package.
- Live source-agent request through the built Mac executable: discovery, session creation, model response, and cleanup all returned HTTP 200. See [Agent review](AGENT_REVIEW.md). One successful request is a smoke test, not a formal agent evaluation.
- Native rendering and visual inspection of all four populated screens, empty Plan and Focus, and Plan at 950 × 730. Fixed a truncated side heading and made the selected timer duration visible. Smaller windows use vertical scrolling for content below the viewport.
- Shell syntax, property-list validation, and whitespace checks.

Screenshots in `docs/previews/` contain synthetic examples. Rendering uses an in-memory workspace and never loads or replaces the user's saved app data.

## Not established by these checks

- Full interactive acceptance testing of every control, VoiceOver navigation, and physical Mac sleep/wake. Timer recovery is tested with explicit timestamps and persistence, not a recorded physical sleep cycle.
- Older macOS versions, Intel Macs, cross-device data migration, notarization, or App Store distribution.
- Clinical outcomes or formal quality evaluations of the unchanged source agent. Source-server telemetry export errors remain documented in the agent review.
- Safari interception or live Linear sync. Neither is implemented or claimed.

## First use check

Capture a real thought, add it to Plan, enter a next action, and start a short focus block. Confirm a pause and resume. Complete a step, enter the next one, then quit and reopen the app. Check that the task and editor buffers remain. Enable the companion only when ready to send selected context to the existing Gemini service.
