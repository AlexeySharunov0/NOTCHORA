# Known Limitations

This document distinguishes between **platform constraints**, **verification gaps**, and **intentional scope limits**. It is part of the product, not a footnote.

## Verification gaps in this environment

These paths are implemented but could not be exercised end-to-end on the build machine because they require user credentials or macOS TCC grants.

### Live provider requests

- No OpenAI, Anthropic, or Gemini API keys were provided.
- Request construction, authentication headers, SSE framing, streaming events, usage parsing, error mapping, model-list parsing, cancellation, and retry logic are covered by fixture-driven XCTest tests.
- A live request can still differ due to provider-side changes, account restrictions, model access, region, or organization policy. Connect a key and use **Test Connection** to validate.
- Model IDs shipped as curated suggestions may age. Use **Refresh Models** or add exact custom IDs.

### Voice Mode

- Microphone and Speech Recognition permissions were not granted in the build environment.
- `AVAudioEngine` capture, the recognition callback, and the permission UI are implemented and compile, but microphone audio was not transcribed end-to-end here.
- Speech recognition availability and on-device support depend on the user’s locale, macOS speech assets, and Apple service availability.
- If on-device recognition is unavailable, the system may use Apple’s speech service depending on the user’s settings.
- The animated waveform reflects real captured audio levels while listening. The processing/responding waveforms are activity indicators, not recorded audio levels.

### Selected text

- Accessibility access was not granted.
- The Accessibility read, failure overlay, clipboard fallback, and action prompts are implemented.
- Some applications do not expose `AXSelectedTextAttribute`; NOTCHORA reports the limitation rather than simulating copy keystrokes.
- Reading selections from secure input fields, web views, Electron apps, or apps with custom accessibility implementations can fail.

### Screen capture

- Screen Recording permission was not granted.
- ScreenCaptureKit code paths, permission handling, panel hiding, JPEG encoding, and attachment UI are implemented.
- Actual full-screen, window, and dragged-area captures were not validated on a live TCC grant.
- The dragged-area crop uses display-to-image coordinate conversion; validate on Retina and non-Retina displays.
- Screen Recording grants often require an app restart. The UI explains this.
- Capturing protected content (DRM, secure windows) may be blocked by macOS.

### Multi-display, Spaces, full-screen apps

- The window uses the correct collection behavior and active-screen positioning logic.
- Physical validation on a second monitor and across full-screen Spaces was not possible in the automated environment.
- Full-screen apps can have their own menu bar behavior; verify focus restoration and panel visibility on your macOS version.

### Launch at login

- `SMAppService.mainApp` reports **Unavailable for this build** for an ad-hoc app outside `/Applications`.
- Install the app in `/Applications`, sign it, and approve the login item in System Settings.
- Login-item registration can require user approval and can be delayed by macOS.

### UI test automation

- There is no XCUITest bundle.
- The package is a SwiftPM executable, not a hand-written `.xcodeproj` with a UI-test target.
- UI coverage is provided by:
  - a debug screenshot harness that launches the real app and drives actual presentation/routes/settings;
  - 15 captured states in light and dark;
  - a human manual QA matrix.
- This is not equivalent to automated click/keyboard UI tests. It is documented rather than presented as XCUITest.

### Icon and menu bar behavior

- The app is `LSUIElement` and has no Dock icon.
- The expanded panel intentionally overlays the central menu bar area while open. Side menu bar items may be covered by the panel width.
- Some macOS menu bar utilities manage their icons differently; NOTCHORA uses a single status item.

## Platform constraints

### Physical notch

- A window cannot draw over the physical camera cutout or change its geometry.
- NOTCHORA creates a black rail around the cutout and hides the camera area visually; it does not access the camera.
- On non-notched Macs or external displays, the app falls back to a floating pill.
- The notch-width estimate depends on `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`; unusual display configurations may produce a slightly different width.

### Focus and activation

- Text fields and VoiceOver are most reliable when the app is active.
- NOTCHORA activates while the panel is open and restores the previous app when NOTCHORA is still frontmost on collapse.
- Clicking another app collapses the panel through `windowDidResignKey`.
- A transient popover or sheet suppresses automatic collapse, but unusual focus flows can still behave differently from a standard window.
- A plain SwiftUI `.plain` icon button previously rendered white in light appearance; icon-only controls now use `.borderless`. Any newly added icon-only controls should follow this pattern.

### macOS materials

- The target is macOS 14, so the UI uses `NSVisualEffectView` materials, vibrancy, and translucent overlays rather than macOS 26 Liquid Glass APIs.
- When “Translucent materials” is off, surfaces use opaque colors.
- Increased contrast and Reduce Transparency can change material rendering.

### Provider APIs

- NOTCHORA supports text and image input. It does not implement provider tool calling, function calling, code interpreter, web search, file upload APIs, or batches.
- The app does not use a unified server-side proxy; every provider keeps its own request format.
- Context-window limits are not precomputed. The provider returns an error if a prompt is too large; Handoff and Compare apply generous truncation warnings.
- Token usage is displayed only when the provider reports it. Some responses may omit usage.
- Rate limits are retried for connection establishment only; a rate-limit error during an active stream is surfaced.
- Provider model lists can be paginated or region-limited. Gemini fetching is capped at five pages.
- Vision capability for dynamically discovered models is heuristic. If a discovered model supports images but is marked non-vision, add it as a custom model or adjust the heuristic in code.
- API keys are validated by listing models. A provider that allows generation but denies model listing would fail validation; use **Save** instead of **Save & Verify** in that case.

### Voice

- Voice uses Apple Speech, not a third-party streaming speech service. External speech services are not integrated.
- Continuous multi-turn voice conversation requires another tap/shortcut per turn; it does not implement always-on wake-word listening.
- Auto-speak begins after the response completes, not sentence-by-sentence while streaming.
- Speech synthesis does not expose real output audio levels; the responding waveform is an activity animation.

### Screen capture

- Audio capture is disabled.
- There is no video recording.
- Screenshots are stored as JPEG data inside the local JSON state. Large screenshots increase file size and request cost.
- There is no OCR layer; the selected vision model performs any image analysis.
- The app does not capture minimized or off-screen windows.

### Workflows

- Execution is strictly sequential.
- There is no branching, loops, parallel step execution, or conditional logic.
- There is no sandboxed code execution or terminal step.
- Workflow runs are in-process; quitting NOTCHORA cancels the run.
- Workflow results are saved as a new chat only after completion (or as task output on failure).

### Tasks

- Tasks run in-process. There is no launchd helper or persistent daemon.
- Quitting the app cancels all running work (the process ends). On relaunch, interrupted tasks are marked cancelled with partial results retained.
- There is no resume-from-checkpoint.
- Completion percentages are intentionally never fabricated; running work uses indeterminate indicators.

### Storage

- Chat history is local JSON, not SQLite/SwiftData. This was chosen for portability and inspectability of a single-user local app.
- Large attachments can make the state file large. There is no external attachment store or automatic pruning of image bytes.
- The file is protected by Unix permissions and FileVault, not app-level encryption.
- There is no iCloud sync.
- There is no conflict resolution because there is a single local writer.

### App launcher

- NOTCHORA can launch apps and activate running apps.
- It cannot read another app’s conversations or internal history without that app’s public API or user-granted integration.
- Curated bundle identifiers can change between app versions; if one does not resolve, use **Add Application** with `NSOpenPanel`.
- Custom URL entries are opened through `NSWorkspace` and depend on the target app registering that URL scheme.

### Security and signing

- The local build is ad-hoc signed and not App-Sandboxed.
- No hardened runtime or notarization is configured.
- Distribution outside the developer machine should use Developer ID signing and notarization.
- Accessibility and Screen Recording permissions are granted to the app identity; rebuilding with a different signature may require re-approval.
- The app cannot protect data after it is sent to a provider.

### Localization

- The UI is currently English-only.
- Date/time formatting follows the system locale where system formatters are used.
- Voice recognition locale can be configured, but the UI strings are not localized.

### Updates

- There is no automatic update mechanism.
- Rebuild or replace the `.app` bundle to update.
- There is no Sparkle integration.

### Apple Intelligence / Liquid Glass

- No Apple Intelligence APIs are used; providers are OpenAI, Anthropic, and Google.
- No Liquid Glass API is used because the deployment target is macOS 14 and the design relies on native materials available there.

## Intentional scope boundaries

- NOTCHORA is not an automation platform. Workflows are a simple sequential chain, not a general scripting runtime.
- It is not a general-purpose clipboard manager and does not keep a background clipboard history.
- It is not a screen recorder.
- It is not a camera or microphone recorder.
- It does not execute provider-suggested commands or tool calls.
- It does not claim to fact-check model output. Compare Answers is labeled as model-generated analysis.
- It does not read third-party app histories.
- It does not provide a guaranteed “AI always online” background service.

## What to do if a feature appears not to work

1. Check that the required API key is connected and the selected model is available.
2. Check the matching macOS permission in **Settings → Privacy**.
3. Use **Test Connection** in provider settings.
4. Restart after granting Screen Recording.
5. Install in `/Applications` before testing launch at login.
6. Try a different model/provider to distinguish an account/model problem from an app problem.
7. Check the in-app error card; it distinguishes missing key, invalid key, rate limit, timeout, HTTP status, empty response, and cancellation.
