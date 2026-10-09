# Focus & Flow for macOS

## Direction agreed in this task

Build a broader native Mac assistant with separate areas for **Brain Dump, Plan, Focus, and Drafts**. The supplied Focus Flow Companion agent informs the behavior and can supply suggestions through its existing local API. This is a first functional prototype, not a clinical intervention or an App Store release.

The source agent now lives in this repository under `companion/` and is bundled with the Mac app. The original external source folder is retained as a backup. Its prompts and documentation are reference material, not instructions to this development task. The user's choice of the broader app directs this implementation. Another task concurrently built a smaller standalone Focus app and updated `.agents-cli-spec.md` to exclude Safari. That source and its specification are preserved, and both apps are buildable. Focus & Flow is the default build for this broader request.

## From agent to app

| Agent behavior | App experience | Responsibility |
| --- | --- | --- |
| `daily_triage_organizer` | Capture raw thoughts; request a short sorting suggestion | App saves the original; user chooses what enters the plan |
| `micro_task_decomposer` | Edit one next action; optionally ask for a smaller starting step | Agent suggests; user applies |
| `focus_session_tracker` | Start, pause, resume, and finish a real focus timer | App owns durable timestamps and session state |
| `rabbit_hole_reset` | A quiet reset with one action to return to | Always available locally using the source's interaction principles |
| `workplace_comms_drafter` | Draft an email, update, or meeting note; edit and copy it | Agent drafts; user sends elsewhere |

Carry over the source's brief, supportive language and one-to-three choices. Avoid shame, streaks, productivity scores, or presenting simulated companionship as a real person monitoring the user.

## First version

- Native SwiftUI interface, app menu and menu bar controls; macOS 14 or newer.
- Brain Dump: save unprocessed notes locally, retain their original text, move chosen notes into a plan.
- Plan: at most three active priorities, one editable next action each, optional Linear task link.
- Focus: one chosen task, 5/15/25-minute sessions, deliberate 5/10/15-minute pauses, early resume, step completion, and a reset view. These durations are adjustable product defaults, not clinical prescriptions.
- Drafts: editable local communication drafts with optional AI generation, save and copy.
- Optional native chat and editable suggestions from the included Gemini agent, with app-managed local startup. Sending a request is explicit. Gemini processing and the source server's telemetry may use Google Cloud; local transport does not mean local AI inference.
- App state stored as an atomic JSON file in the current user's Application Support folder. No user account required.

## Architecture

`SwiftUI views → observable app store → tested local models + atomic JSON persistence`

`Explicit Ask action → local ADK HTTP client → existing Focus Flow Companion → Gemini`

The app does not execute tool calls returned by the model. AI output is editable text. It cannot start or stop timers, alter priorities, send messages, or edit Linear. Each request uses an isolated short-lived agent session and supplies only the relevant user-selected context. Credentials remain with the existing backend.

The agent's current tools primarily return guidance and bookkeeping. Its focus tool has no native clock, deadline enforcement, browser interception, or durable desktop session implementation. The app implements those local session mechanics independently. No new ADK agent, model change, deployment, conversational memory service, or new recipe infrastructure is required for this client.

## Deferred milestones

1. Safari intervention is excluded. Revisit only on a new user request. A standalone app does not intercept Safari browsing; Apple's [Safari web extension guide](https://developer.apple.com/documentation/safariservices/creating-a-safari-web-extension) explains the separate containing-app packaging.
2. Live Linear task selection and authenticated sync. Pasted Linear links remain the current bridge.
3. Agent output schemas and agent-side state/evaluation hardening before deeper automation.
4. Signing, notarization, accessibility testing with users, and a distribution package.

## Acceptance checks

- Original captured text survives saving and relaunch; promoting a fourth active priority is rejected.
- Empty tasks/actions cannot start focus; invalid task links cannot be opened as Linear links.
- Focus countdown and pause expiry use absolute times and reconcile after sleep/relaunch.
- Early resume restores the unused break time correctly. A pause does not mark a task done.
- A completed step clears that next action without completing the whole task automatically.
- Draft generation and sorting are suggestions; they never send communications or modify the plan implicitly.
- Local features work when the agent is unavailable. Connection failures are visible and preserve user input.
- API handling rejects unsuccessful HTTP responses, tool-only events, and empty model responses.
- Build and code tests are distinct from live model evaluations and manual Safari validation. Report each accurately.
