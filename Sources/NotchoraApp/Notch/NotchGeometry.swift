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
        topRailHeight = max(screen.safeAreaInsets.top, hasPhysicalNotch ? 37 : 0)
        screenWidth = screen.frame.width
        screenName = screen.localizedName
    }
}

@MainActor
enum NotchGeometry {
    static let compactHeightWithNotch: CGFloat = 41
    static let fallbackCompactHeight: CGFloat = 34
    static let expandedSize = CGSize(width: 548, height: 664)
    static let workspaceSize = CGSize(width: 1120, height: 722)

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
            let width = compactWidth(on: screen)
            let height = notched ? compactHeightWithNotch : fallbackCompactHeight
            let top = notched ? screen.frame.maxY + 1 : visible.maxY - 4
            return centeredFrame(width: width, height: height, top: top, screen: screen)
        case .expanded:
            let width = min(expandedSize.width, screen.frame.width - 24)
            let height = min(expandedSize.height, visible.height - 18)
            let top = notched ? screen.frame.maxY : visible.maxY - 4
            return centeredFrame(width: width, height: height, top: top, screen: screen)
        case .workspace:
            let width = min(workspaceSize.width, screen.frame.width - 32)
            let height = min(workspaceSize.height, visible.height - 16)
            let top = visible.maxY - 6
            return centeredFrame(width: width, height: height, top: top, screen: screen)
        }
    }

    static func compactWidth(on screen: NSScreen) -> CGFloat {
        let notchedWidth: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notchedWidth = screen.frame.width - left.width - right.width
        } else {
            notchedWidth = 190
        }
        let extra: CGFloat = isNotched(screen) ? 92 : 68
        return min(max(notchedWidth + extra, 260), screen.frame.width - 24)
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
