# Privacy and Security

## Summary

NOTCHORA is a local macOS client. It has:

- no analytics;
- no telemetry;
- no crash-reporting SDK;
- no proxy server;
- no background clipboard monitor;
- no hidden screen or microphone capture;
- no stored pointer history; while compact, only the current pointer position around the notch is checked to support click/hover opening;
- no account system.

When you send a prompt, the request goes **directly over HTTPS** from this Mac to the provider you selected. The provider’s own privacy policy and retention rules apply.

## Data map

| Data | Where it lives | Protection |
|---|---|---|
| API keys | macOS Keychain, service `com.notchora.app.credentials` | Keychain item, accessible after first unlock |
| Conversations and messages | `~/Library/Application Support/NOTCHORA/state.json` | File mode `0600`, directory `0700`, atomic writes |
| Image/context attachments | Embedded in local conversation state | Same local file protections |
| Task results and workflow definitions | Same state file | Same |
| Launcher entries and preferences | `UserDefaults` / local state | Non-secret |
| Provider requests | Sent to the selected vendor over HTTPS | HTTPS only; no logging of keys |
| API errors | Displayed to the user | Redacted for common key patterns |

NOTCHORA does not write API keys, Authorization headers, or provider request bodies to logs. The one persistent log path used by `StateStore` logs only local file problems, never message content.

## Keychain

- Uses `SecItem` generic-password items.
- One account per provider: `api-key.openai`, `api-key.anthropic`, `api-key.gemini`.
- Existing values are never displayed back in the UI.
- Remove keys from **Settings → AI Providers** or **Settings → Privacy → Remove API keys**.
- The debug QA harness uses an in-memory key store and never touches the real Keychain.

## Local history

State is stored in one JSON file. It is not encrypted by NOTCHORA beyond the protection of the macOS user account and disk encryption. If you need encryption at rest beyond FileVault, do not store sensitive conversations locally, or remove them after use.

History controls:

- **Keep chat history** off → conversations are deleted and subsequent snapshots contain no chats.
- **Maximum conversations** → oldest unpinned conversations are pruned after the limit.
- **Delete conversations** → removes local chats.
- **Delete all local data** → removes chats, tasks, workflows, and launcher entries.
- **Remove API keys** → deletes all provider credentials from Keychain.

Corrupt state files are moved aside as `state.corrupt-<timestamp>.json` rather than silently overwritten.

## Network behavior

Only these destinations are contacted:

- `api.openai.com`
- `api.anthropic.com`
- `generativelanguage.googleapis.com`

No other network calls are made. The app does not bundle analytics, ads, update checkers, or remote configuration.

Model list refreshes and key verification contact the provider’s model-list endpoint. They do not send conversation content. Chat requests send only:

- the system prompt and messages in the active request;
- text attachments explicitly added by you;
- image attachments explicitly added by you.

Handoff, compare, workflows, and multi-AI may send conversation content or results to the chosen provider; the UI identifies the target provider before those actions.

## Microphone

- Requested only when Voice Mode starts.
- Active only while the state is **Listening**.
- `AVAudioEngine` is stopped and its tap removed when listening ends, Voice Mode closes, or the panel collapses.
- Speech recognition uses Apple’s Speech framework. When the selected recognizer supports on-device recognition, NOTCHORA requests it. Otherwise Apple’s speech service may process audio according to the system’s Speech settings.
- No audio file is persisted by NOTCHORA.

## Screen capture

- Requested only when you choose **Capture Screen…** and then a capture mode.
- Uses ScreenCaptureKit.
- Hides the NOTCHORA panel before capture.
- Shows the attached image in the composer.
- Sends it only when you press Send.
- Does not record continuously or in the background.
- Screen Recording permission is controlled by macOS TCC.
- The debug visual QA harness captures its **own** window via `NSView.cacheDisplay`, not the screen.

## Clipboard

- Read only after an explicit **Use Clipboard** or **Use Clipboard Text** action.
- Never polled or monitored in the background.
- Clipboard writes occur only when you press a Copy control.

## Pointer location while compact

- The compact surface is exactly the hardware notch, so NOTCHORA checks the pointer position around the cutout to support click and optional hover opening.
- Only the current screen coordinate is tested against the notch hit zone. It is not stored, logged, or sent anywhere.
- No screen content, window content, clipboard content, or key events are read by this check.
- The check is active only while the panel is compact.

## Accessibility / selected text

- Used only when you invoke **Ask Selected Text** (`⌥S`) or the attach menu action.
- Reads the focused UI element’s selected text through the Accessibility API once.
- Does not simulate copy keystrokes.
- Does not inspect other windows unless needed to read the focused element.
- If Accessibility is denied or the app does not expose a selection, NOTCHORA explains the failure and offers the clipboard fallback.

## AI app launcher

- Uses `NSWorkspace` to locate and launch applications.
- Does not read another app’s internal history, databases, or private APIs.
- Uses public URL schemes only when explicitly configured for a custom entry.
- Does not capture other apps’ windows unless you separately invoke Screen Capture.

## Prompt injection and untrusted context

Text from documents, websites, messages, selected text, clipboard, images, and model output is untrusted content.

- It is never executed as shell commands.
- It is never used to automatically launch apps, send messages, delete data, or change settings.
- Handoff wraps imported context as untrusted conversational material and instructs the receiving model not to treat it as system instructions.
- Context actions wrap selected text in an explicit reference block.
- Model output is displayed; it is not automatically acted upon.

No application can guarantee that a language model will ignore all injected instructions. Users should review actions and never paste secrets into a provider they do not trust.

## Third parties

When you use a provider, your prompt, attachments, and relevant conversation context are governed by that provider’s terms and privacy policy:

- OpenAI: <https://openai.com/policies/privacy-policy>
- Anthropic: <https://www.anthropic.com/legal/privacy>
- Google: <https://policies.google.com/privacy>
- DeepSeek: <https://platform.deepseek.com/privacy>

NOTCHORA does not control provider retention, training, logging, or regional processing.

## Permissions

| Permission | Optional? | Feature |
|---|---|---|
| Microphone | Yes | Voice input |
| Speech Recognition | Yes | Voice transcription |
| Accessibility | Yes | Selected-text actions |
| Screen Recording | Yes | Screen context |

Denying any permission disables only the matching feature. The rest of the app remains usable.

## Security limitations

- The app is not App-Sandboxed in the current local build.
- The build is ad-hoc signed for development; distribution requires Developer ID signing and notarization.
- The local state file is protected by file permissions and FileVault, not application-level encryption.
- API keys are protected by Keychain, but the app process can read them while running.
- The app cannot protect data after it has been sent to a provider.
- Provider rate limits and model behavior are outside NOTCHORA’s control.

## Reporting a security issue

Do not open a public issue containing an API key or private conversation. Rotate any exposed key immediately. Report privately to the maintainer listed in the repository metadata.
