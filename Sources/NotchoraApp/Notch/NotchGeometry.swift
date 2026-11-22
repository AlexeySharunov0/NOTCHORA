import AppKit
import Foundation
import NotchoraCore
import Observation

@MainActor
@Observable
final class NotchEnvironment {
    var hasPhysicalNotch = false
    var topRailHeight: CGFloat = 38
    var notchWidth: CGFloat = 200
    var screenWidth: CGFloat = 1440
    var screenHeight: CGFloat = 900
    var screenName = "Display"
    var isFallback = false

    func update(for screen: NSScreen) {
        let left = screen.auxiliaryTopLeftArea
        let right = screen.auxiliaryTopRightArea
        let detectedWidth: CGFloat
        if let left, let right {
            detectedWidth = max(120, screen.frame.width - left.width - right.width)
        } else {
            detectedWidth = 200
        }
        hasPhysicalNotch = screen.safeAreaInsets.top > 0 && left != nil && right != nil
        isFallback = !hasPhysicalNotch
        notchWidth = detectedWidth
        topRailHeight = max(screen.safeAreaInsets.top, hasPhysicalNotch ? 32 : 0)
        screenWidth = screen.frame.width
        screenHeight = screen.frame.height
        screenName = screen.localizedName
    }
}

@MainActor
enum NotchGeometry {
    static let compactHeightWithNotch: CGFloat = 32
    static let fallbackCompactHeight: CGFloat = 34
    static let hoverPreviewExtra: CGFloat = 28
    static let expandedSize = CGSize(width: 860, height: 540)
    static let workspaceSize = CGSize(width: 1180, height: 700)

    static func preferredScreen(settings: SettingsStore) -> NSScreen {
        let screens = NSScreen.screens
        switch settings.displayPreference {
        case .builtIn:
            if let builtIn = screens.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }) {
                return builtIn
            }
            if let notched = screens.first(where: { isNotched($0) }) {
                return notched
            }
            return NSScreen.main ?? screens.first ?? NSScreen.screens[0]
        case .main:
            return NSScreen.main ?? screens.first ?? NSScreen.screens[0]
        case .activeScreen:
            let mouse = NSEvent.mouseLocation
            return screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
                ?? NSScreen.main
                ?? screens.first
                ?? NSScreen.screens[0]
        }
    }

    static func isNotched(_ screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 0
            && screen.auxiliaryTopLeftArea != nil
            && screen.auxiliaryTopRightArea != nil
    }

    static func frame(
        for presentation: PanelPresentation,
        on screen: NSScreen
    ) -> CGRect {
        let notched = isNotched(screen)
        let visible = screen.visibleFrame

        switch presentation {
        case .hidden:
            return .zero
        case .compact:
            let width = min(compactWidth(on: screen) + hoverPreviewExtra, screen.frame.width)
            let height = notched ? compactHeightWithNotch : fallbackCompactHeight
            let top = notched ? screen.frame.maxY : visible.maxY - 4
            return centeredFrame(width: width, height: height, top: top, screen: screen)
        case .expanded:
            let width = min(expandedSize.width, screen.frame.width - 20)
            let height = min(expandedSize.height, screen.frame.height - 20)
            let top = notched ? screen.frame.maxY : visible.maxY - 4
            return centeredFrame(width: width, height: height, top: top, screen: screen)
        case .workspace:
            let width = min(workspaceSize.width, screen.frame.width - 24)
            let height = min(workspaceSize.height, screen.frame.height - 24)
            let top = notched ? screen.frame.maxY : visible.maxY - 4
            return centeredFrame(width: width, height: height, top: top, screen: screen)
        }
    }

    static func surfaceSize(
        for presentation: PanelPresentation,
        environment: NotchEnvironment
    ) -> CGSize {
        switch presentation {
        case .hidden:
            return .zero
        case .compact:
            if environment.hasPhysicalNotch {
                return CGSize(
                    width: min(max(environment.notchWidth, 120), environment.screenWidth),
                    height: compactHeightWithNotch
                )
            }
            return CGSize(
                width: min(250, environment.screenWidth - 24),
                height: fallbackCompactHeight
            )
        case .expanded:
            return CGSize(
                width: min(expandedSize.width, environment.screenWidth - 20),
                height: min(expandedSize.height, environment.screenHeight - 20)
            )
        case .workspace:
            return CGSize(
                width: min(workspaceSize.width, environment.screenWidth - 24),
                height: min(workspaceSize.height, environment.screenHeight - 24)
            )
        }
    }

    static func compactWidth(on screen: NSScreen) -> CGFloat {
        let notchedWidth: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notchedWidth = screen.frame.width - left.width - right.width
        } else {
            notchedWidth = 190
        }
        if isNotched(screen) {
            return min(max(notchedWidth, 120), screen.frame.width)
        }
        return min(250, screen.frame.width - 24)
    }

    private static func centeredFrame(
        width: CGFloat,
        height: CGFloat,
        top: CGFloat,
        screen: NSScreen
    ) -> CGRect {
        CGRect(
            x: screen.frame.midX - width / 2,
            y: top - height,
            width: width,
            height: height
        )
    }
}
