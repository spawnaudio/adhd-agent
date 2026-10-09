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


## Integrated Gemini companion — 10 October 2026

The original Focus & Flow ADK companion was imported into `companion/`. Its six Python agent/runtime source files match the external source apart from blank-line whitespace cleanup. The Gemini model, tool definitions, and instructions are unchanged. Only the new native bootstrap and launcher adapt storage/startup. Generated traces, logs, Python environments, old sessions, and private configuration are excluded from the repository and app bundle.

Current checks:

- `xcrun swift test --scratch-path .build` with the Xcode beta toolchain: 28 tests passed, zero failures. This includes old workspace decoding, conversation persistence, multi-turn session reuse, transport failure preservation, and the existing timer/data rules.
- `sh scripts/build-app.sh`: release app built and replaced the existing `dist/Focus & Flow.app`.
- `codesign --verify --deep --strict` and `plutil -lint`: passed, including after backend use.
- Built app `--check-companion --port 18800`: started the bundled backend, obtained a real Gemini suggestion, and confirmed two-turn conversation continuity. Its owned backend stopped after the check.
- Integrated backend `/list-apps` and A2A agent-card endpoints: HTTP 200.
- Imported evaluation dataset: all four cases ran. Existing `custom_response_quality` judge scored task overwhelm, distraction recovery, workplace drafting, and focus sprint guidance 5/5 each; mean 5.0, four valid cases, zero evaluation errors. This is the existing response rubric, not a clinical or production-readiness assessment.
- Native GUI: Companion sidebar and settings displayed; enabling Gemini automatically started the bundled backend; a real reply appeared in native chat. Quit/relaunch stopped and restarted the owned backend, restored the native transcript, and a follow-up correctly recalled the earlier reply. One cloud request timed out; its text was restored in the input and the explicit retry succeeded. Transport tests now distinguish slow replies from an unavailable server.

The companion chat handles conversation and guidance. The native Focus area remains responsible for actual countdowns and local focus state. No ChatGPT/MCP port, cloud deployment, prompt tuning, notarization, or distribution packaging was performed. First startup needs installed `uv`, network access for missing locked packages, and local Google configuration; this Mac's existing setup was reused.
