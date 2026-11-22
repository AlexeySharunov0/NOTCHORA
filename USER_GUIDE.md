# NOTCHORA — Step-by-step guide

## 1. Open the app

Install and launch `NOTCHORA.app`. On first launch the notch surface expands and shows the welcome screen.

The compact state is **exactly the physical MacBook notch**: no ears, chin, logo, or status line. Because there are no extra software pixels, use one of these reliable ways to open it:

- press **⌥Space**;
- click the NOTCHORA item in the menu bar and choose **Open NOTCHORA**;
- click the cutout area itself. Hovering it first slightly widens the black shape so you can see the hit target; clicking then opens the panel. This is optional and may depend on how macOS delivers pointer events over the camera housing.

The surface stretches horizontally out of the notch and settles into the expanded workspace. Press **Esc** or click outside to collapse.

## 2. Connect an AI provider

1. Open **Settings → AI Providers**. Use **⌘,** or the menu-bar item.
2. Choose a card: **OpenAI**, **Anthropic**, **Google Gemini**, or **DeepSeek**.
3. Paste the API key into the provider’s field.
4. Click **Save & Verify**. The app validates the key by listing models.
5. Click **Refresh Models** to replace the curated list with the provider’s current models.
6. Use the rail’s **Chat** icon to return to the conversation.

Keys are stored only in the macOS Keychain. They are never written to settings, history, or logs.

Provider key pages:

- OpenAI: <https://platform.openai.com/api-keys>
- Anthropic: <https://console.anthropic.com/settings/keys>
- Google AI Studio: <https://aistudio.google.com/app/apikey>
- DeepSeek: <https://platform.deepseek.com/api_keys>

DeepSeek is text-only. Image attachments and screen capture are blocked while a DeepSeek model is active.

## 3. Chat

1. Open the model picker in the chat header and choose a provider/model.
2. Type in the composer and press **Return** to send.
3. **Shift+Return** inserts a newline.
4. Use the stop control to cancel a stream; partial output stays visible.
5. Copy, regenerate, pin, rename, or delete the conversation from the header and message actions.
6. Open **History** from the rail to search all conversations.
7. Use **Settings → General** to change the default provider/model, response behavior, and notch settings.

## 4. Multi-AI and Compare Answers

1. Open **Multi-AI** from the rail.
2. Select two or more provider/models with connected keys.
3. Send one prompt; each model streams independently.
4. Cancel or retry individual answers.
5. Use **Compare** to ask a chosen model for an agreement/tension summary. It is explicitly labelled as model-generated, not a fact check.

## 5. Handoff

1. In a conversation, click **Handoff**.
2. Choose **Full conversation**, **Selected messages**, or **Summary**.
3. Pick the target provider/model.
4. Review the editable transferred context.
5. Optionally enable **Continue automatically**.
6. Click **Hand off**.

## 6. Voice Mode

1. Press **⌥V** or click the waveform in the composer.
2. Grant Microphone and Speech Recognition permission when macOS asks.
3. Speak; press the control to stop and send.
4. Enable **Speak replies** to hear answers.
5. The microphone is active only while listening.

## 7. Add context

- **Selected text:** select text in another app and press **⌥S**, or choose **Ask Selected Text** from the composer plus menu. Accessibility permission is required.
- **Clipboard:** choose **Use Clipboard Text** from the plus menu. Nothing is polled in the background.
- **Screen capture:** choose **Capture Screen…**, select full screen, current window, or a dragged area, then press **Capture**. Screen Recording permission is required; macOS may ask for a restart.
- Screen images are sent only to vision-capable models. DeepSeek is text-only.

## 8. Tasks, workflows, and AI apps

- **Tasks:** background generations survive panel collapse. Open **Tasks** to inspect running/completed/failed work, cancel, copy results, or clear finished tasks.
- **Workflows:** create a sequence of model steps with prompts and optional system prompts. Run it from the workflow list; results are saved to history.
- **AI Apps:** add installed applications, open or switch to them, and manage custom entries from the grid.

## 9. Settings

Use **⌘,** or the menu-bar item. Settings opens inside the notch workspace:

- **General:** launch at login, menu-bar item, default action, default provider/model, hover behavior, display choice.
- **AI Providers:** API keys, validation, model refresh, custom model IDs.
- **Shortcuts:** change the six global actions, enable/disable, reset, see registration conflicts.
- **Appearance:** system/light/dark for menus and AppKit controls, density, animation preference. The notch surface itself always stays opaque black to match the hardware cutout.
- **Privacy:** permission status, history limits, delete conversations, delete all local data, remove all API keys.
- **About:** version and product information.

## 10. Permissions

Grant only what you use in **System Settings → Privacy & Security**:

- **Microphone** — Voice Mode.
- **Speech Recognition** — transcription.
- **Accessibility** — reading the text you explicitly selected.
- **Screen Recording** — capturing the screen for an image attachment.

If selected text is unavailable, use the Clipboard fallback. NOTCHORA never simulates copy keystrokes.

## 11. Data and privacy

- API keys: Keychain service `com.notchora.app.credentials`.
- Local state: `~/Library/Application Support/NOTCHORA/state.json`, file mode `0600`.
- No analytics or telemetry.
- No hidden clipboard, microphone, or screen capture.
- Delete keys and local data under **Settings → Privacy**.
- While compact, NOTCHORA checks only the current pointer position around the cutout to show the hover preview and handle clicks; it does not store or send pointer history.

## 12. Default shortcuts

| Action | Shortcut |
|---|---|
| Open / collapse | `⌥Space` |
| New Chat | `⌥N` |
| Voice Mode | `⌥V` |
| Ask Selected Text | `⌥S` |
| Multi-AI | `⌥M` |
| Hide Panel | `⌥.` |

Change them in **Settings → Shortcuts**. A shortcut without Command, Option, or Control is rejected.

## 13. Troubleshooting

- **The notch looks slightly larger than the hardware** — compact is measured from `safeAreaInsets.top` and the auxiliary top areas; on the test 14-inch display this is 185×32 pt. If your Mac needs an inset, report the display model and a screenshot.
- **Nothing happens when clicking the notch** — use **⌥Space** or the menu-bar item; the exact hardware cutout may not deliver pointer events on every Mac.
- **I pressed Return without a key and nothing was sent** — the draft stays in the composer and a Connect toast appears. NOTCHORA no longer jumps to AI Providers on its own; press **Connect** in the toast or open Settings manually. The draft is preserved when you return to Chat.
- **No API key banner** — connect the selected provider in Settings.
- **Invalid key** — verify the key, provider, and **Test Connection**.
- **Rate limit** — wait, retry, or switch model/provider.
- **Screen capture fails** — grant Screen Recording, restart, and ensure the target window is visible.
- **Launch at login unavailable** — install the app in `/Applications` and approve the login item.

See [README.md](README.md), [INSTALLATION.md](INSTALLATION.md), [PRIVACY.md](PRIVACY.md), [TESTING.md](TESTING.md), and [LIMITATIONS.md](LIMITATIONS.md) for deeper documentation.
