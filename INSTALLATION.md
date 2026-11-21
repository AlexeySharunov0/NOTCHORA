# Installation and Setup

## Requirements

- macOS 14.0 (Sonoma) or newer
- Xcode 16 or newer, with Swift 6
- Apple Silicon or Intel Mac
- A valid API key for at least one provider

Tested on macOS 26.6 with Xcode 26.6 / Swift 6.3. The deployment target is macOS 14.0.

## Build and launch

From the repository root:

```bash
./Scripts/build-app.sh
open build/NOTCHORA.app
```

Or:

```bash
make app
make run
```

The script:

1. builds the release package with a workspace-local SwiftPM cache;
2. generates `build/AppIcon.icns` if needed;
3. assembles `build/NOTCHORA.app`;
4. copies `Resources/Info.plist` and the icon;
5. ad-hoc signs the bundle for local TCC attribution.

For development:

```bash
make build      # debug build
make test       # XCTest
make qa         # debug screenshot QA
```

## Install into Applications

For the most reliable permission and login-item behavior, copy the app to `/Applications`:

```bash
cp -R build/NOTCHORA.app /Applications/
open /Applications/NOTCHORA.app
```

Launch at login uses `SMAppService.mainApp`. An ad-hoc build launched from a build directory may report **Unavailable for this build**; install the app before enabling the login item.

## First run

On first launch, NOTCHORA expands the notch panel and shows the welcome screen.

1. Click **Open AI Provider Settings** (or use the menu bar item → Settings).
2. Open **AI Providers**.
3. Paste a key into the provider card.
4. Click **Save & Verify**.
5. Optionally click **Refresh Models**.
6. Close Settings and click the notch to return to chat.

Keys are saved in Keychain only after verification succeeds. Choose **Save** instead of **Save & Verify** if you want to store a key without a network check.

## Provider setup

### OpenAI

- Endpoint: `https://api.openai.com/v1`
- Key page: <https://platform.openai.com/api-keys>
- Key format: `sk-…`
- Requests use `chat/completions` with SSE streaming.
- The model list is fetched from `GET /v1/models` and filtered to chat-capable families.

### Anthropic

- Endpoint: `https://api.anthropic.com/v1`
- Key page: <https://console.anthropic.com/settings/keys>
- Key format: `sk-ant-…`
- Requests use `POST /v1/messages` with named SSE events.
- The model list is fetched from `GET /v1/models`.

### Google Gemini

- Endpoint: `https://generativelanguage.googleapis.com/v1beta`
- Key page: <https://aistudio.google.com/app/apikey>
- Key format: `AIza…`
- Requests use `streamGenerateContent?alt=sse`.
- The model list is fetched from `GET /v1beta/models`; only models supporting `generateContent` are shown.

If a newly released model is missing, either click **Refresh Models** or add its exact API identifier under **Custom models**.

## Permissions

Open **System Settings → Privacy & Security** and grant only the permissions you use.

### Accessibility

Used by **Ask Selected Text**.

1. Trigger `⌥S` with text selected, or use the attach menu.
2. If access is missing, NOTCHORA explains the limitation and offers **Grant Accessibility**.
3. Enable NOTCHORA in System Settings.
4. Try again.

Some apps do not expose their selection through Accessibility. In that case, copy the text and use **Use Clipboard**.

### Microphone and Speech Recognition

Used only in Voice Mode.

1. Press `⌥V` or click the waveform button in the composer.
2. macOS asks for microphone and speech access.
3. Speak; press **Stop & Send** or wait for the recognizer to finalize.
4. The app transcribes, sends to the selected model, and optionally speaks the reply.

The microphone is active only while the voice state is **Listening**. Closing Voice Mode stops the audio engine.

### Screen Recording

Used only when you choose to attach a screen capture.

1. Open the composer’s attach menu → **Capture Screen…**.
2. Choose Full Screen, Current Window, or Selected Area.
3. macOS shows a Screen Recording permission prompt if needed.
4. Grant access; macOS may require restarting NOTCHORA.
5. Capture. The image is attached to the composer for review.
6. Press Send to transmit it to the selected model.

The panel hides itself before capture. Nothing is sent until you press Send.

If macOS keeps returning an empty capture list after granting access, quit and relaunch the app. This is a macOS TCC behavior, not an app preference.

## Launch at login

1. Install `NOTCHORA.app` in `/Applications`.
2. Open **Settings → General**.
3. Enable **Launch at login**.
4. Approve the login item if macOS asks in **System Settings → General → Login Items**.

The setting reflects the actual `SMAppService.mainApp.status`. If the app is not installed or is unsigned, macOS may reject registration and NOTCHORA reports the error.

## Default shortcuts

| Action | Shortcut |
|---|---|
| Open / collapse | `⌥Space` |
| New Chat | `⌥N` |
| Voice | `⌥V` |
| Selected text | `⌥S` |
| Multi-AI | `⌥M` |
| Hide | `⌥.` |

Change them in **Settings → Shortcuts**. Press a new combination in the recorder. If macOS rejects it because another app owns it, the row shows the registration error. A combination without Command, Option, or Control is rejected.

## Where data lives

```text
~/Library/Application Support/NOTCHORA/state.json   # chats, tasks, workflows, launcher entries
~/Library/Preferences/com.notchora.app.plist        # non-secret preferences and window frame
Keychain service: com.notchora.app.credentials      # API keys
```

`state.json` is written atomically with mode `0600`. It contains conversation text, task results, workflow definitions, and image attachment data, but **never** API keys.

Delete data with **Settings → Privacy**:

- Delete conversations;
- Delete all local data (chats, tasks, workflows, launcher entries);
- Remove API keys from Keychain.

## Uninstall

1. Quit NOTCHORA from the menu bar.
2. Remove `/Applications/NOTCHORA.app`.
3. Remove `~/Library/Application Support/NOTCHORA`.
4. Remove `~/Library/Preferences/com.notchora.app.plist`.
5. Remove API keys via Keychain Access (`com.notchora.app.credentials`) if you did not delete them in the app.

## Troubleshooting

| Symptom | Action |
|---|---|
| Panel opens then immediately collapses | Click the notch again; ensure NOTCHORA is the active app, or check that another app is not grabbing focus |
| No API key banner | Connect the selected provider in Settings → AI Providers |
| “Invalid API key” | Verify the key and provider; use Test Connection |
| Model not found | Refresh the model list or add the exact model ID under Custom models |
| Rate limit | Wait, switch model/provider, or retry |
| Screen capture error | Grant Screen Recording, restart the app, and ensure the target window is not minimized |
| Selected text unavailable | Grant Accessibility or use Clipboard fallback |
| Launch at login unavailable | Install the app in `/Applications` and approve the login item |
| Shortcut does nothing | Check Settings → Shortcuts for a registration conflict |
| Settings window not visible | Use menu bar item → Settings; the window opens as a normal resizable window |

## Build notes

If you build from a restricted shell and SwiftPM cannot write its caches, use the repository scripts. They set `TMPDIR`, `CLANG_MODULE_CACHE_PATH`, and workspace-local SwiftPM cache paths, and pass `--disable-sandbox` to SwiftPM. This is a build-environment workaround; it does not affect the app’s runtime sandboxing (the app is not App-Sandboxed).

The app is ad-hoc signed. For distribution outside your Mac, replace the ad-hoc identity with a Developer ID certificate and notarize the bundle. No entitlements beyond normal user-selected permissions are required for the current non-sandboxed build.
