# Use Focus & Flow

## Open the Mac app

1. Open `dist/Focus & Flow.app` from this repository in Finder.
2. In **Brain Dump**, type a thought and select **Save this thought**. Your original wording is retained.
3. Select **Add to plan** for one thought. In **Plan**, select it and write one small next action.
4. Choose 5, 15, or 25 minutes, then select **Start focus**. **I did this step** records the step and lets you enter the next one. It does not finish the entire task.
5. For a break, select **Pause focus**, choose its length, and select **Confirm pause**. You can resume early. After the break expires, the focus countdown resumes.

**Drafts** has a notes box and an editable draft. You can write manually, save a copy, or copy the draft to another app. Nothing is sent automatically.

The leaf in the Mac menu bar opens the app and shows the active timer. Closing the window keeps the app running there. Use **Focus & Flow → Quit Focus & Flow** to quit fully. Active deadlines are saved; elapsed time still counts while the app is closed or the Mac sleeps. No alert or sound is emitted while the app is quit.

## Use the included Gemini companion

The app's ordinary features work without AI. To use the original Focus & Flow agent inside the app:

1. Open **Companion settings** and enable **Gemini companion**. The app starts its included backend automatically. The first start prepares the locked Python dependencies using your installed `uv`.
2. Once the status says **Your companion is ready**, select **Done** and open **Companion** in the sidebar.
3. Write a message and select **Send** (Command-Return). Follow-up messages share this conversation's agent session. The current conversation survives app relaunches.
4. **Help me sort it**, **Help me find a step**, and **Help me write it** continue to provide isolated, editable suggestions. They do not attach your companion chat or apply changes automatically.
5. Disable the companion to stop the backend started by the app. Quitting the app also stops its own backend; closing its window keeps the menu bar app running.

The integrated agent source is `companion/`. The build includes the agent's source and dependency lock in `dist/Focus & Flow.app`; it excludes credentials, Python environments, generated logs, and old conversations. The original external agent folder was preserved as a backup.

### Local setup and storage

Install [uv](https://docs.astral.sh/uv/) if it is unavailable. Google configuration belongs in:

`~/Library/Application Support/FocusFlow/companion/.env`

Use `companion/.env.example` as the setup reference. During this integration, the existing local Google configuration was copied here without changing its values. Existing Google application-default credentials remain in their normal location. New checkouts must supply their own configuration.

The runtime Python environment, SQLite agent sessions, and `server.log` live in the same private Application Support directory. The app starts the server on loopback only. A manually started compatible server on the configured port can be reused; the app does not stop a server it did not launch.

For command-line development, `Start Companion.command` now starts the in-repo agent. `FOCUS_FLOW_AGENT_DIR` can point to another copy of the integrated companion, and `FOCUS_FLOW_AGENT_PORT` can select a different local port.

**Data flow:** Sending a chat message shares that conversation with Gemini. Explicit suggestion requests send their relevant text in separate temporary sessions. Your other notes and plan are not implicitly attached. Gemini inference uses your configured Google service; localhost does not make the model local. Existing backend/provider telemetry can apply. Starting a new conversation changes the native view; it does not delete Google/provider logs or earlier backend sessions.

## Where work is saved

Notes, plan items, drafts, unfinished editor text, and session timestamps are saved in:

`~/Library/Application Support/FocusFlow/workspace.json`

The app writes this file atomically with permissions limited to the current user. It is ordinary local JSON, not separately encrypted by this app. If it cannot read the existing file, it leaves the file untouched and prevents editing instead of silently replacing it. If saving fails, keep the app open and resolve the disk or permissions issue before quitting.

To reopen a finished task, expand **Finished** in Plan and choose **Restore**. It returns to Brain Dump so it doesn't unexpectedly crowd your priorities.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Command-N | Open Brain Dump |
| Command-1 / 2 / 3 / 4 | Plan / Brain Dump / Focus / Drafts |
| Command-5 | Companion chat |
| Command-Return | Send a companion message |
| Command-0 | Show the app window |
| Command-comma | Companion settings |
| Command-W | Close the window; keep the menu bar app running |
| Command-Q | Quit the app |

These are app shortcuts, not global shortcuts that intercept typing in other apps.

## Build and develop

Open `Package.swift` in Xcode, or run `sh scripts/build-app.sh` from this repository. The script creates the app bundle under `dist/` and signs it ad hoc for local use. It selects the installed Xcode beta when no developer directory is specified; it does not change the Mac's global Xcode selection. Set `DEVELOPER_DIR` to use another full Xcode installation.

Run `xcrun swift test` with the same Xcode selected to run the core and transport tests. The initial system Command Line Tools installation had a compiler/SDK mismatch; the full Xcode beta built successfully.

Minimum deployment target: macOS 14. The supplied local binary was built and checked on Apple Silicon with macOS 27 beta. Compatibility with older macOS releases and Intel Macs has not been tested. This is a local prototype, not a notarized distribution build.

## Current boundaries

- No Safari extension or browsing intervention. The smaller app's standalone specification is preserved in `.agents-cli-spec.md`.
- Linear works through an optional pasted HTTPS issue link. No live task sync is implemented.
- The companion provides editable text suggestions; brain dump sorting does not automatically create separate tasks.
- Local support includes a brief reset view. No medical diagnosis or treatment functionality is implemented.
- This version has no cloud sync, global capture shortcut, background reminders, or app auto-launch at login.
