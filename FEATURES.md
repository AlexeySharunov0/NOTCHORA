# Implemented Features

This is the functional inventory of the current build. “Implemented” means the code path exists and is reachable. Live provider calls require a valid key; TCC-dependent features require the matching macOS permission.

## Notch experience

- Compact notch extension around the physical MacBook cutout.
- Physical notch detection using `NSScreen` auxiliary areas and safe-area insets.
- Fallback compact pill on non-notched displays.
- Open from the exact-notch compact state with the global shortcut or menu-bar item; the cutout area also accepts pointer events where macOS delivers them.
- Hover preview: slightly widens the cutout under the pointer; click opens.
- One continuous opaque-black surface that grows downward and outward from the physical notch.
- No material, blur, glass, border, drop shadow, or separate floating workspace window.
- Spring shape animation with content fading in after expansion begins.
- Expanded surface with history, tasks, apps, Multi-AI, workspace, and collapse controls.
- Full workspace with sidebar, conversation list, route navigation, and background generation.
- Multi-display anchoring using an active-screen / built-in / main preference.
- `canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary`, and `.statusBar` window behavior.
- Save/restore focus of the previously frontmost app.
- Non-notched fallback pills retain the idle activity indicator; the exact-notch compact surface has no software content.
- Compact surface is exactly the hardware cutout: no ears, chin, logo, line, or activity counter.
- Escape / hide shortcut / click-outside collapse.
- Reduce Motion and in-app animation preference.
- System menus and AppKit controls follow the system/light/dark preference.
- The notch surface itself is always opaque black so it merges with the hardware cutout.
- Monochrome black-and-white app icon generated from a vector draw script.

## AI providers

### OpenAI

- Chat Completions SSE streaming.
- Text and vision requests.
- System prompt.
- Dynamic model list with chat-family filtering.
- Reasoning-model temperature handling.
- Usage tokens.
- Key validation and model refresh.

### Anthropic

- Messages API SSE streaming.
- Named streaming events.
- Text, vision, system prompts.
- Dynamic model list.
- Usage tokens.
- Key validation and model refresh.

### Google Gemini

- `streamGenerateContent` SSE.
- System instructions.
- Text and inline image input.
- Dynamic model list filtered to `generateContent`.
- Usage metadata.
- Key validation and model refresh.

### DeepSeek

- OpenAI-compatible Chat Completions SSE at `api.deepseek.com`.
- `deepseek-v4-pro` and `deepseek-flash` (legacy IDs can be added as custom models).
- `max_tokens` request field and Bearer authentication.
- Reasoning deltas are not displayed as chat text; the final content is.
- Text-only: image attachments and screen capture are blocked for DeepSeek models.
- Dynamic model list, usage tokens, key validation, and custom model IDs.

### Provider infrastructure

- Unified `AIProvider` protocol.
- Provider registry and dependency injection.
- Keychain-only credentials.
- Custom model IDs.
- Streaming cancellation.
- Retry policy for retryable HTTP/network errors.
- Timeouts.
- Error mapping to human-readable messages.
- Redaction of key-shaped strings in provider error bodies.
- No fake responses.

## Chat

- Multiple conversations.
- New chat, rename, delete, pin, search.
- Conversation switching from the header and history.
- Per-chat provider/model selection.
- Per-chat system prompt.
- Markdown headings, lists, quotes, tables, links, emphasis, inline code.
- Fenced code blocks with language label and syntax highlighting.
- Copy code block.
- Copy message.
- Regenerate last answer.
- Stop generation and keep partial output.
- Sending without an API key keeps the draft in chat, shows an inline Connect action, and does not jump to Settings; the draft survives a Settings round-trip.
- Hovering the compact cutout widens it by 28 pt as a hit-target preview; clicking opens.
- Empty, streaming, complete, failed, and cancelled message states.
- Error cards with retry and provider settings actions.
- Token usage and duration metadata.
- Text/image attachment display.
- Image attachments open in Preview.
- Long-answer scrolling.
- Auto-scroll to the latest message.
- Debounced local persistence.
- History search and provider/pinned filters.
- Plain-text previews without Markdown syntax.

## Multi-AI

- One prompt to multiple models.
- Provider/model multi-select.
- Parallel independent streams.
- Independent status per model.
- Independent cancellation.
- Independent retry.
- Independent token usage.
- Side-by-side adaptive result grid.
- Scrollable result cards.
- Copy individual results.
- Compare Answers with a chosen model.
- Streaming comparison.
- Explicit “model-generated, not an objective fact check” disclaimer.
- Save complete session to history.
- Comparison saved with the session when complete.

## AI Handoff

- Full conversation transfer.
- Selected-message transfer.
- AI-generated summary mode.
- Editable transferred context.
- Target provider/model picker.
- Context size warning.
- Secure system instruction for untrusted transcript.
- Optional automatic continuation in the new chat.
- New chat stored in history.

## Voice Mode

- Microphone permission request.
- Speech Recognition permission request.
- `AVAudioEngine` capture with a live audio tap.
- `SFSpeechRecognizer` partial/final transcription.
- On-device recognition when available.
- Animated level waveform.
- Listening, processing, responding, interrupted, ready, and error states.
- Send recognized speech to the active conversation/model.
- Speech synthesis of the response.
- Auto-speak preference.
- Speech rate preference.
- Locale preference.
- Interrupt speech and generation.
- Stop microphone on close/collapse.
- Clear permission and provider-setup errors.

## Context awareness

### Selected text

- Accessibility focused-element read.
- Source application name.
- Editable selected-text preview.
- Explain, Summarize, Translate, Improve, Rewrite, Ask AI, Generate Reply.
- Context is wrapped as untrusted reference material.
- Accessibility-denied / unsupported-app explanation.
- Clipboard fallback.

### Clipboard

- Explicit read only.
- Attach clipboard text as context.
- AI actions on clipboard text.
- No polling, no hidden monitoring.
- Copy messages/code/results to the clipboard.

### Screen capture

- ScreenCaptureKit screenshot manager.
- Full-screen capture.
- Frontmost-window capture.
- Dragged-area capture overlay.
- Panel hidden before capture.
- JPEG compression and downscaling.
- Composer preview before sending.
- Explicit permission explanation.
- Screen capture error handling.

## AI task manager

- Background task records for chat, Multi-AI, compare, workflow, and voice.
- Pending, running, completed, failed, cancelled states.
- Indeterminate progress indicators (no fabricated percentages).
- Result preview and copy.
- Cancel and stop all.
- Open related chat.
- Remove individual tasks.
- Clear finished tasks.
- Persist results locally.
- Recover interrupted tasks as cancelled after relaunch.

## AI app launcher

- Curated entries for ChatGPT, Claude, Cursor, Perplexity, and Warp.
- Detection through `NSWorkspace`.
- Installed/running state.
- Open or activate.
- Add custom application via `NSOpenPanel`.
- Remove entries.
- Reset suggestions.
- Refreshes running state while the view is visible.
- No reading of third-party histories.

## Workflows

- Sequential multi-step workflows.
- Original / previous / all-previous input modes.
- `{{input}}` substitution or appended input.
- Per-step provider/model.
- Per-step prompt template.
- Per-step optional system prompt.
- Create, edit, duplicate, delete.
- Reorder steps.
- Visual editor.
- Three presets: Code Review, Research Brief, Polish Writing.
- Real API execution per step.
- Step-by-step status.
- Cancellation.
- Failure reporting.
- Combined report.
- Result conversation saved to history.
- No percentage progress.

## Settings

### General

- Launch at login.
- Menu bar item visibility.
- Default action.
- Default provider/model.
- Default system prompt fallback.
- Temperature and max output tokens.
- Hover preview.
- Display preference.
- Reset general settings.

### AI Providers

- Secure key entry.
- Save and verify.
- Save without testing.
- Test Connection.
- Refresh Models.
- Remove key.
- Provider key page links.
- Keychain status.
- Model counts.
- Custom model add/remove.
- Per-provider test result messages.

### Shortcuts

- All six global actions configurable.
- Enable/disable each.
- Shortcut recorder with modifier capture.
- Conflicting/unsafe shortcut rejection.
- Registration error display.
- Reset all.
- Carbon registration.

### Appearance

- System/light/dark for system menus and AppKit controls.
- Fixed opaque-black notch surface.
- Interface density.
- Panel animation preference.
- Live preview.
- Appearance applied without changing the notch material.

### Privacy

- Permission status for microphone, speech, accessibility, screen recording.
- Request/open System Settings actions.
- Keep history toggle with deletion confirmation.
- Maximum conversations.
- Delete conversations.
- Delete all local data.
- Remove all API keys.
- Privacy by construction summary.

### About

- Version/build.
- Native/private/direct.
- Product description.
- No analytics statement.

## Single-surface UI

- Chat, history, tasks, apps, workflows, Multi-AI, settings, and the model picker render inside the notch.
- Handoff, system-prompt, screen-capture, voice, selection, and workflow-editor surfaces are in-notch overlays, not sheets or separate windows.
- Settings opened from the status menu, Cmd+, or the app menu expands the same notch workspace.
- The only external macOS panels are transient menus and the explicit app/file picker required to add an app.

## Security and persistence

- Keychain API keys.
- API keys absent from state and defaults.
- Atomic JSON storage.
- `0600` file / `0700` directory.
- Corrupt-state quarantine.
- Schema version guard.
- HTTPS-only endpoints.
- No secrets in logs.
- Explicit permissions.
- Data deletion controls.
- No hidden capture or clipboard polling.
- Prompt/context treated as untrusted data.

## Quality

- 58 XCTest unit tests.
- Fixture-driven provider streaming tests.
- State persistence tests.
- Keychain abstraction tests.
- Task/workflow tests.
- Settings persistence tests.
- Debug visual QA harness with 30 screenshots, including expansion/collapse frames and overlays.
- Monochrome black-and-white app icon.
- Pixel validation of the opaque-black, welded, centered notch shape.
- Reduced-motion shape checks.
- Reduced Motion handling.
- Retina 2× capture.
- App bundle build script.
- Generated app icon.
- Ad-hoc signing.

See [LIMITATIONS.md](LIMITATIONS.md) for the boundaries of what was verified.
