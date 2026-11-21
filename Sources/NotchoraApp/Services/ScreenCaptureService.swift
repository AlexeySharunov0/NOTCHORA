import AppKit
import CoreGraphics
import CoreVideo
import NotchoraCore
import ScreenCaptureKit

struct ScreenCaptureResult: Sendable {
    var image: CGImage
    var label: String
}

enum ScreenCaptureError: Error, LocalizedError, Sendable {
    case permissionDenied
    case noDisplay
    case noWindow
    case selectionCancelled
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Screen Recording permission is required to share a screen with an AI model."
        case .noDisplay:
            "No matching display was found."
        case .noWindow:
            "No capturable window was found for the frontmost app."
        case .selectionCancelled:
            "Screen selection was cancelled."
        case let .captureFailed(message):
            "Screen capture failed: \(message)"
        }
    }
}

@MainActor
final class ScreenCaptureService {
    var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    func captureFullScreen(screen: NSScreen) async throws -> ScreenCaptureResult {
        guard hasPermission else { throw ScreenCaptureError.permissionDenied }
        let content = try await shareableContent()
        guard let display = content.displays.first(where: {
            $0.displayID == screen.displayID
        }) ?? content.displays.first else {
            throw ScreenCaptureError.noDisplay
        }

        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        let filter = SCContentFilter(display: display, excludingWindows: [])
        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            return ScreenCaptureResult(image: image, label: "\(screen.localizedName) — Full Screen")
        } catch {
            throw ScreenCaptureError.captureFailed(error.localizedDescription)
        }
    }

    func captureCurrentWindow(preferredPID: pid_t? = nil) async throws -> ScreenCaptureResult {
        guard hasPermission else { throw ScreenCaptureError.permissionDenied }
        let content = try await shareableContent()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let frontmostPID: pid_t? = {
            if let frontmost, frontmost != ownPID { return frontmost }
            if let preferredPID, preferredPID != ownPID { return preferredPID }
            return nil
        }()

        let candidates = content.windows.filter { window in
            guard window.isOnScreen,
                  window.windowLayer == 0,
                  window.frame.width >= 240,
                  window.frame.height >= 160,
                  window.owningApplication?.processID != ownPID else { return false }
            if let frontmostPID {
                return window.owningApplication?.processID == frontmostPID
            }
            return true
        }
        guard let window = candidates.max(by: {
            ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height)
        }) else {
            throw ScreenCaptureError.noWindow
        }

        let scale = NSScreen.screens.first(where: {
            $0.frame.contains(NSPoint(x: window.frame.midX, y: window.frame.midY))
        })?.backingScaleFactor ?? 2
        let configuration = SCStreamConfiguration()
        configuration.width = Int(window.frame.width * scale)
        configuration.height = Int(window.frame.height * scale)
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        let filter = SCContentFilter(desktopIndependentWindow: window)
        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            let appName = window.owningApplication?.applicationName ?? "Current Window"
            let title = window.title?.isEmpty == false ? " — \(window.title!)" : ""
            return ScreenCaptureResult(image: image, label: "\(appName)\(title)")
        } catch {
            throw ScreenCaptureError.captureFailed(error.localizedDescription)
        }
    }

    func captureSelectedArea() async throws -> ScreenCaptureResult {
        guard hasPermission else { throw ScreenCaptureError.permissionDenied }
        guard let selection = await AreaSelectionController.selectArea() else {
            throw ScreenCaptureError.selectionCancelled
        }
        try await Task.sleep(for: .milliseconds(120))
        let full = try await captureFullScreen(screen: selection.screen)
        guard let cropped = crop(
            full.image,
            screenRect: selection.rect,
            screen: selection.screen
        ) else {
            throw ScreenCaptureError.captureFailed("The selected area could not be cropped.")
        }
        return ScreenCaptureResult(image: cropped, label: "Selected Area — \(selection.screen.localizedName)")
    }

    func attachment(from result: ScreenCaptureResult) -> ChatAttachment? {
        guard let data = jpegData(from: result.image) else { return nil }
        return ChatAttachment(
            kind: .screenCapture,
            name: "\(result.label).jpg",
            mimeType: "image/jpeg",
            data: data
        )
    }

    private func shareableContent() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            if !hasPermission { throw ScreenCaptureError.permissionDenied }
            throw ScreenCaptureError.captureFailed(error.localizedDescription)
        }
    }

    private func crop(_ image: CGImage, screenRect: CGRect, screen: NSScreen) -> CGImage? {
        let scaleX = CGFloat(image.width) / screen.frame.width
        let scaleY = CGFloat(image.height) / screen.frame.height
        let x = (screenRect.minX - screen.frame.minX) * scaleX
        let yTop = (screen.frame.maxY - screenRect.maxY) * scaleY
        let rect = CGRect(
            x: x,
            y: yTop,
            width: screenRect.width * scaleX,
            height: screenRect.height * scaleY
        ).integral
        guard rect.width > 1, rect.height > 1 else { return nil }
        return image.cropping(to: rect)
    }

    private func jpegData(from image: CGImage, maxDimension: CGFloat = 2560) -> Data? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let ratio = min(1, maxDimension / max(width, height))
        let targetSize = NSSize(width: max(1, width * ratio), height: max(1, height * ratio))

        let source = NSImage(cgImage: image, size: targetSize)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: source.size),
            operation: .copy,
            fraction: 1
        )
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

private struct AreaSelection: @unchecked Sendable {
    var rect: CGRect
    var screen: NSScreen
}

@MainActor
private final class AreaSelectionController {
    private static var activeController: AreaSelectionController?
    private let completion: (AreaSelection?) -> Void
    private var windows: [NSWindow] = []
    private var didFinish = false
    private var selectionViews: [AreaSelectionView] = []

    private init(completion: @escaping (AreaSelection?) -> Void) {
        self.completion = completion
    }

    static func selectArea() async -> AreaSelection? {
        await withCheckedContinuation { continuation in
            let controller = AreaSelectionController { selection in
                continuation.resume(returning: selection)
                AreaSelectionController.activeController = nil
            }
            activeController = controller
            controller.begin()
        }
    }

    private func begin() {
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            let view = AreaSelectionView(frame: NSRect(origin: .zero, size: screen.frame.size), screen: screen)
            view.onSelection = { [weak self] rect in
                self?.finish(rect: rect, screen: screen)
            }
            view.onCancel = { [weak self] in self?.finish(rect: nil, screen: screen) }
            window.contentView = view
            windows.append(window)
            selectionViews.append(view)
        }
        NSApp.activate(ignoringOtherApps: true)
        for window in windows {
            window.makeKeyAndOrderFront(nil)
        }
        windows.first?.makeKey()
    }

    private func finish(rect: CGRect?, screen: NSScreen) {
        guard !didFinish else { return }
        didFinish = true
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        if let rect, rect.width > 8, rect.height > 8 {
            completion(AreaSelection(rect: rect, screen: screen))
        } else {
            completion(nil)
        }
    }
}

@MainActor
private final class AreaSelectionView: NSView {
    let screen: NSScreen
    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var dragOrigin: NSPoint?
    private var dragCurrent: NSPoint?
    private var isDragging = false

    init(frame frameRect: NSRect, screen: NSScreen) {
        self.screen = screen
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setFillColor(NSColor.black.withAlphaComponent(0.42).cgColor)
        context.fill(bounds)

        if let rect = currentRect {
            context.setBlendMode(.clear)
            context.fill(rect)
            context.setBlendMode(.normal)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            context.setLineWidth(1.5)
            context.stroke(rect)

            let size = "\(Int(rect.width)) × \(Int(rect.height))"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let sizeText = NSAttributedString(string: size, attributes: attributes)
            let textSize = sizeText.size()
            let labelRect = NSRect(
                x: rect.minX + 6,
                y: max(rect.minY - textSize.height - 8, 8),
                width: textSize.width + 12,
                height: textSize.height + 6
            )
            NSColor.black.withAlphaComponent(0.72).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 5, yRadius: 5).fill()
            sizeText.draw(at: NSPoint(x: labelRect.minX + 6, y: labelRect.minY + 3))
        }

        let hint = "Drag to select an area  ·  Esc to cancel"
        let hintAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85)
        ]
        let hintText = NSAttributedString(string: hint, attributes: hintAttributes)
        let hintSize = hintText.size()
        hintText.draw(at: NSPoint(
            x: bounds.midX - hintSize.width / 2,
            y: bounds.maxY - 54
        ))
    }

    private var currentRect: NSRect? {
        guard let origin = dragOrigin, let current = dragCurrent else { return nil }
        return NSRect(
            x: min(origin.x, current.x),
            y: min(origin.y, current.y),
            width: abs(current.x - origin.x),
            height: abs(current.y - origin.y)
        )
    }

    override func mouseDown(with event: NSEvent) {
        dragOrigin = convert(event.locationInWindow, from: nil)
        dragCurrent = dragOrigin
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        dragCurrent = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        dragCurrent = convert(event.locationInWindow, from: nil)
        guard let rect = currentRect, rect.width > 8, rect.height > 8 else {
            NSSound.beep()
            dragOrigin = nil
            dragCurrent = nil
            needsDisplay = true
            return
        }
        let windowRect = convert(rect, to: nil)
        let screenRect = window?.convertToScreen(windowRect) ?? rect
        onSelection?(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
