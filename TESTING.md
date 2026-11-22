# Testing and Quality Assurance

## Test commands

```bash
make test
# or
swift test
```

The suite uses XCTest and does not call the network or the real Keychain.

Current result (recorded during development):

```text
Executed 55 tests, with 0 failures
```

## Unit test coverage

### `SSEParserTests`

- blank-line event dispatch;
- multi-line `data:` fields;
- comments/keep-alives;
- `[DONE]` terminator;
- CRLF normalization;
- flush without a trailing blank line;
- event-only frames.

### `ProviderTests`

- OpenAI streaming text and usage;
- OpenAI reasoning-model temperature omission;
- OpenAI request headers/model/stream/system prompt;
- Anthropic named SSE events, header/version, max tokens, system prompt;
- Gemini SSE text/usage, `x-goog-api-key`, streaming URL;
- invalid-key mapping (401/403);
- rate-limit mapping (429);
- missing-key failure before network;
- OpenAI model-list filtering;
- Anthropic model-list parsing;
- Gemini model-list prefix stripping and capability filtering;
- SSE error payloads mapped to stream errors.

Tests use a `MockTransport` that implements `HTTPTransport`; no live calls are made. Fixtures are representative SSE frames for each provider.

### `ChatCoreTests`

- adjacent turn merging;
- text attachment embedding;
- vision capability rejection;
- transcript-starting-with-assistant normalization;
- `AIService.complete` aggregation;
- missing key and empty completion errors;
- concurrent independent streams;
- Compare request construction and disclaimer;
- Handoff draft, selected-message context, and summary request;
- History filtering, pinned/provider filters, query excerpts;
- Markdown-to-plain-text previews;
- conversation previews.

### `StorageTests`

- full state round trip;
- file mode `0600`;
- corrupt state quarantine;
- unsupported future schema;
- in-memory Keychain behavior;
- API key never written to state JSON.

### `SettingsTests`

- defaults and safe shortcut validation;
- enum/string persistence across `SettingsStore` instances;
- shortcut conflict detection;
- custom shortcut persistence and reset;
- unsafe modifier rejection;
- model selection defaults.

### `TaskCenterTests`

- lifecycle transitions;
- partial result retention;
- cancellation;
- clear-finished;
- recovery of running tasks as cancelled;
- active-first sorting;
- `cancelAll` with bound cancellation handles (also guards against mutating a dictionary during iteration).

### `WorkflowTests`

- sequential execution;
- previous-step input substitution;
- all-previous-steps report;
- failure stops the workflow;
- real event ordering.

### `ModelCatalogTests`

- custom model persistence;
- duplicate rejection;
- discovered model replacement;
- fallback resolution for unknown selections;
- keychain-backed refresh through an injected service.

## What the unit tests deliberately do not do

- They do not contact OpenAI, Anthropic, or Google.
- They do not access the user’s real Keychain.
- They do not grant TCC permissions.
- They do not capture the screen or microphone.
- They do not automate clicks or keyboard input.

Those checks are separated into visual QA and the manual matrix below.

## Automated visual QA

```bash
make qa
# or
./Scripts/visual-qa.sh
```

The debug-only `QAHarness` is activated by `NOTCHORA_QA=1`. It:

1. clears the in-memory provider keys;
2. captures the compact idle notch and onboarding state;
3. injects a fixture conversation and placeholder keys in an in-memory Keychain;
4. captures expanded chat and workspace in system dark and system light (the notch surface remains black);
5. navigates to History, Tasks, Workflows, and Multi-AI;
6. opens Settings inside the notch workspace and captures General, Providers, and Privacy;
7. opens the model picker, Handoff, System Prompt, Screen Capture, Voice, and Workflow Editor as in-notch overlays;
8. captures intermediate expansion and collapse frames of the actual surface;
9. terminates with a success code;
10. writes 29 PNG files and a `runtime-status.txt` report under `build/screenshots/qa`.

The harness uses `NSView.cacheDisplay` so it does not need Screen Recording permission. It is compiled out of release builds. It never touches the real Keychain or Application Support because it uses an in-memory key store and `NOTCHORA_STATE_PATH=build/qa-state.json`.

The script fails if any expected screenshot is missing or empty, if global shortcut registration reported an error, if the composer did not receive keyboard focus, or if the notch-shape pixel validator finds a non-black edge, a surface that is not centered while growing, or a rectangular bottom corner.

### Visual QA observations

- The compact surface is a black extension around the physical notch with a tiny activity mark; it contains no logo or task counter.
- Expanded onboarding, chat, history, tasks, workflows, and Multi-AI layouts were inspected at 620×720 points.
- The workspace was inspected at 1180×780 points.
- The surface was captured at 70 ms, 170 ms, 350 ms, and settled during expansion, and at 80/200/400 ms during collapse. A Swift validator confirms that every sampled surface edge is opaque black, the top edge is welded, the growing shape stays horizontally centered, and the lower corners are transparent.
- Settings, model picker, Handoff, System Prompt, Screen Capture, Voice, and Workflow Editor were verified as in-notch surfaces rather than separate windows.
- The former translucent card/material styling was removed; content now sits directly on opaque black.
- Duplicate keys and raw Markdown in previews were found and fixed.

See [QA.md](QA.md) for the screenshot index.

## Manual QA matrix

These checks require a Mac with a physical notch, a GUI session, and optionally a second display. Check each item and record the macOS version.

### Window behavior

- [ ] The compact black surface appears welded to the physical notch, with no visible seam or border.
- [ ] Expanding from compact shows one black shape growing down and outward; no separate rectangle appears under the notch.
- [ ] The expanded surface is uniformly opaque black; there is no blur, glass, gray fill, or outer stroke.
- [ ] Content fades in after the black shape has started growing.
- [ ] Collapsing returns the same black shape to the compact notch size.
- [ ] Click compact → expanded.
- [ ] Click outside → collapse; previous app regains focus.
- [ ] Hover expansion works when enabled.
- [ ] Escape collapses.
- [ ] Full workspace uses the same welded surface, not a second floating window.
- [ ] Settings opens inside the notch workspace from Cmd+, the app menu, and the status menu.
- [ ] Model picker, Handoff, System Prompt, Screen Capture, Voice, and Workflow Editor fill the in-notch surface rather than opening sheets/popovers.
- [ ] Fallback pill appears on a Mac or display without a notch.
- [ ] Panel appears on the display under the pointer.
- [ ] Moving the pointer to another display and invoking the shortcut repositions the panel.
- [ ] Panel appears over a full-screen app.
- [ ] Switching Spaces keeps the panel at the top.
- [ ] Menu bar item toggles visibility.

### AI chat

- [ ] Connect an OpenAI key, refresh models, send a prompt.
- [ ] Connect Anthropic and Gemini and repeat.
- [ ] Streaming text appears incrementally.
- [ ] Stop keeps partial output and marks the message cancelled.
- [ ] Regenerate produces a new answer.
- [ ] Copy copies the message.
- [ ] Markdown headings, lists, tables, links, and code render.
- [ ] Code copy works.
- [ ] Long answers scroll smoothly.
- [ ] Switch models mid-chat.
- [ ] Set a per-chat system prompt and verify behavior changes.
- [ ] Rename/pin/delete/search chats.
- [ ] Restart the app and verify history.

### Multi-AI and handoff

- [ ] Select multiple models with valid keys.
- [ ] Start one prompt; all streams run independently.
- [ ] Cancel one model; others continue.
- [ ] Retry a failed/cancelled target.
- [ ] Compare Answers with a third model.
- [ ] Save Multi-AI session to History.
- [ ] Handoff full conversation to another provider.
- [ ] Handoff selected messages.
- [ ] Generate and edit a summary.
- [ ] Auto-continue after handoff.

### Voice

- [ ] Deny microphone; verify clear error and Settings link.
- [ ] Grant microphone and speech; start Voice Mode.
- [ ] Waveform responds to voice level.
- [ ] Stop & Send transcribes and sends.
- [ ] Reply is spoken when auto-speak is on.
- [ ] Interrupt stops speech/generation.
- [ ] Closing Voice Mode stops the microphone.
- [ ] Verify with VoiceOver.

### Context

- [ ] Select text in Safari/Notes/TextEdit and press `⌥S`.
- [ ] Explain/Summarize/Translate/Improve/Rewrite/Reply.
- [ ] Ask AI opens the composer with context.
- [ ] Accessibility denied → fallback overlay offers Clipboard.
- [ ] Copy text, use attach → Use Clipboard.
- [ ] Screen capture full screen.
- [ ] Screen capture current window.
- [ ] Screen capture selected area; verify crop coordinates.
- [ ] Image preview and Send.
- [ ] Non-vision model rejects the image with a clear message.

### Tasks, apps, workflows

- [ ] Start a long generation, close the panel, reopen; task continues.
- [ ] Cancel from Tasks.
- [ ] Quit during generation; relaunch; task is marked cancelled.
- [ ] Add a custom app, open/switch, remove.
- [ ] Verify NOTCHORA does not read other apps’ history.
- [ ] Run the Code Review preset with valid keys for both providers.
- [ ] Cancel a running workflow.
- [ ] Create, edit, reorder, duplicate, and delete a workflow.
- [ ] Workflow results appear in History.

### Settings, permissions, security

- [ ] Change appearance and verify both panel and Settings update.
- [ ] Toggle translucency and density.
- [ ] Disable animations; verify panel movement respects it.
- [ ] Record a new shortcut; verify it works globally.
- [ ] Attempt a conflicting shortcut; verify error.
- [ ] Test launch at login from `/Applications`.
- [ ] Verify keys are absent from `state.json` and `defaults`.
- [ ] Delete conversations, all local data, and API keys.
- [ ] Verify denied/restricted permission states are explained.

### Error and resilience

- [ ] No API key → connect prompt; no fake response.
- [ ] Invalid key → clear provider error.
- [ ] Offline network → timeout/error; retry works.
- [ ] Rate limit → visible error after retries.
- [ ] Empty provider response → explicit error.
- [ ] Corrupt `state.json` → app starts with quarantined file and a warning.

## Manual QA status in this environment

The development machine was a notched MacBook running macOS 26.6. The following were verified directly:

- app builds and launches through LaunchServices;
- compact, expanded, and workspace surface sizes and top-edge anchoring;
- opaque black shape growth and collapse frames;
- appearance rebuilding while the notch stays black;
- all visual states in the screenshot harness;
- local state writing;
- global hotkey registration success (runtime QA report: `shortcutErrors: none`);
- composer focus after expansion (runtime QA report: `firstResponder: NSTextView`);
- settings opening inside the notch workspace and tab switching;
- 55 unit tests.

The following require resources not available in the build environment and are documented as verification items, not claimed as live-tested:

- live API responses with valid keys;
- microphone/Speech and Screen Recording TCC flows;
- Accessibility selected-text reading from a third-party app;
- full-screen Spaces behavior and a second physical display;
- SMAppService registration for an ad-hoc build.

These limitations are repeated in [LIMITATIONS.md](LIMITATIONS.md).
