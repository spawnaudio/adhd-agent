# Use Focus & Flow

## Open the Mac app

1. Open `dist/Focus & Flow.app` from this repository in Finder.
2. In **Brain Dump**, type a thought and select **Save this thought**. Your original wording is retained.
3. Select **Add to plan** for one thought. In **Plan**, select it and write one small next action.
4. Choose 5, 15, or 25 minutes, then select **Start focus**. **I did this step** records the step and lets you enter the next one. It does not finish the entire task.
5. For a break, select **Pause focus**, choose its length, and select **Confirm pause**. You can resume early. After the break expires, the focus countdown resumes.

**Drafts** has a notes box and an editable draft. You can write manually, save a copy, or copy the draft to another app. Nothing is sent automatically.

The leaf in the Mac menu bar opens the app and shows the active timer. Closing the window keeps the app running there. Use **Focus & Flow → Quit Focus & Flow** to quit fully. Active deadlines are saved; elapsed time still counts while the app is closed or the Mac sleeps. No alert or sound is emitted while the app is quit.

## Use the existing AI companion

The app's ordinary features work without AI. To request suggestions from the supplied agent:

1. Double-click **Start Companion.command** in this repository. Keep its Terminal window open while you want suggestions. It starts the existing agent on this Mac at port 8000, using its existing installation and Google configuration.
2. Open **Companion settings** in the app.
3. Select **Check connection**. The status should say the companion server is available.
4. Enable **agent suggestions**, then select **Done**.
5. Use **Help me sort it**, **Help me find a step**, or **Help me write it**. Review the response and edit it. **Use as next action** and **Use this draft** apply only that suggestion. Brain dump outlines can be copied; choose your actual priorities yourself.

Stopping the server: press **Control-C** in its Terminal window. Stopping the server doesn't affect saved notes or timers.

The launcher expects the existing agent at:

`/Users/squeakyvermin/Developer/Google Enterprise/Agents/focus-flow-companion/`

For a different installation, set `FOCUS_FLOW_AGENT_DIR` before launching it. The launcher uses the existing environment without installing packages or changing its model. If the installation is missing, complete setup in that agent's own repository first.

**Data flow:** Only explicit help requests send the relevant text to the companion. Gemini inference can use Google Cloud; a server on localhost does not make the model local. The source backend includes telemetry. Temporary API sessions are cleaned up on a best-effort basis, but this does not delete backend or provider logs. No Google credentials are stored in the Mac app.

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
