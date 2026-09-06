# Focus & Flow

A native macOS ADHD companion with four areas: **Brain Dump, Plan, Focus, and Drafts**. The supplied Focus Flow Companion agent informs its calm, small-step approach and can provide editable suggestions through its existing API.

Open `dist/Focus & Flow.app`, or run `sh scripts/build-app.sh` to build it. See [Getting started](docs/GETTING_STARTED.md) for your first session, optional AI connection, and keyboard shortcuts.

The app saves notes locally, keeps up to three priorities, runs real focus timers with deliberate pauses, and provides editable communication drafts. AI is optional; Gemini requests use the existing agent backend and can involve Google Cloud. There is no Safari extension or browsing monitoring.

## Project

- [App direction](docs/APP_DIRECTION.md): source-agent mapping, decisions, and boundaries.
- [Live agent review](docs/AGENT_REVIEW.md): feedback obtained from the existing companion.
- [Validation](docs/VALIDATION.md): build, test, and visual checks.
- `Sources/FocusFlowMac`: native interface, menu bar, and app state.
- `Sources/FocusFlowCore`: session rules, persistence, and companion client.
- `Tests/FocusFlowCoreTests`: timer, saved-data, and API transport tests.

Open `Package.swift` in Xcode to develop the app. macOS 14 is the deployment target; the local prototype was built on Apple Silicon with macOS 27 beta. The app is ad-hoc signed for this Mac, not notarized for distribution.

## Earlier single-task app

The smaller **Focus** app from the earlier setup task is preserved under `Sources/FocusApp` and `Sources/FocusCore`, together with its tests and `.agents-cli-spec.md`. Build it separately with `sh scripts/build-app.sh --simple`. Its original usage guide is retained in [Simple Focus](docs/SIMPLE_FOCUS.md).

The two apps keep separate local data. The broader app does not silently migrate or replace the earlier app's saved tasks.
