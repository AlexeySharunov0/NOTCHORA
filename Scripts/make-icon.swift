#!/usr/bin/env swift
import AppKit
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "build/icon-1024.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("No graphics context")
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

// Base squircle.
let outer = NSRect(x: 34, y: 34, width: 956, height: 956)
let outerPath = NSBezierPath(roundedRect: outer, xRadius: 218, yRadius: 218)
let darkTop = NSColor(srgbRed: 0.105, green: 0.11, blue: 0.125, alpha: 1)
let darkBottom = NSColor(srgbRed: 0.025, green: 0.026, blue: 0.032, alpha: 1)
let background = NSGradient(starting: darkTop, ending: darkBottom)
background?.draw(in: outerPath, angle: -90)

// Subtle rim.
NSColor.white.withAlphaComponent(0.14).setStroke()
outerPath.lineWidth = 5
outerPath.stroke()

// Inner glow behind the mark.
let glow = NSGradient(colors: [
    NSColor(srgbRed: 0.30, green: 0.50, blue: 1.0, alpha: 0.34),
    NSColor(srgbRed: 0.10, green: 0.80, blue: 0.72, alpha: 0.07),
    NSColor.clear
])
let glowPath = NSBezierPath(ovalIn: NSRect(x: 180, y: 290, width: 680, height: 680))
glow?.draw(in: glowPath, relativeCenterPosition: .zero)

// Centered brand mark: a luminous squircle with a real notch cut out of its
// top edge, matching the mark used inside the app.
let markRect = NSRect(x: 246, y: 276, width: 532, height: 532)
let markPath = NSBezierPath(roundedRect: markRect, xRadius: 152, yRadius: 152)
let notchHole = NSBezierPath(roundedRect: NSRect(x: 402, y: 732, width: 220, height: 92), xRadius: 40, yRadius: 40)

let mask = NSBezierPath()
mask.windingRule = .evenOdd
mask.append(markPath)
mask.append(notchHole)

context.saveGState()
mask.addClip()
let markGradient = NSGradient(colors: [
    NSColor(srgbRed: 0.37, green: 0.55, blue: 1.0, alpha: 1),
    NSColor(srgbRed: 0.18, green: 0.84, blue: 0.74, alpha: 1)
])
markGradient?.draw(in: markRect, angle: -35)
context.restoreGState()

// Rim and inner shadow give the mark physical depth.
NSColor.white.withAlphaComponent(0.20).setStroke()
markPath.lineWidth = 3
markPath.stroke()

let rim = NSBezierPath(roundedRect: NSRect(x: 260, y: 290, width: 504, height: 504), xRadius: 140, yRadius: 140)
NSColor.black.withAlphaComponent(0.08).setStroke()
rim.lineWidth = 2
rim.stroke()

// Soft halo.
let halo = NSGradient(colors: [
    NSColor(srgbRed: 0.30, green: 0.64, blue: 1.0, alpha: 0.18),
    NSColor.clear
])
let haloPath = NSBezierPath(ovalIn: NSRect(x: 156, y: 186, width: 712, height: 712))
halo?.draw(in: haloPath, relativeCenterPosition: .zero)

// Sparkles.
func sparkle(center: NSPoint, radius: CGFloat, alpha: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x, y: center.y + radius))
    path.curve(
        to: NSPoint(x: center.x + radius, y: center.y),
        controlPoint1: NSPoint(x: center.x + radius * 0.18, y: center.y + radius * 0.18),
        controlPoint2: NSPoint(x: center.x + radius * 0.18, y: center.y + radius * 0.18)
    )
    path.curve(
        to: NSPoint(x: center.x, y: center.y - radius),
        controlPoint1: NSPoint(x: center.x + radius * 0.18, y: center.y - radius * 0.18),
        controlPoint2: NSPoint(x: center.x + radius * 0.18, y: center.y - radius * 0.18)
    )
    path.curve(
        to: NSPoint(x: center.x - radius, y: center.y),
        controlPoint1: NSPoint(x: center.x - radius * 0.18, y: center.y - radius * 0.18),
        controlPoint2: NSPoint(x: center.x - radius * 0.18, y: center.y - radius * 0.18)
    )
    path.curve(
        to: NSPoint(x: center.x, y: center.y + radius),
        controlPoint1: NSPoint(x: center.x - radius * 0.18, y: center.y + radius * 0.18),
        controlPoint2: NSPoint(x: center.x - radius * 0.18, y: center.y + radius * 0.18)
    )
    NSColor.white.withAlphaComponent(alpha).setFill()
    path.fill()
}

sparkle(center: NSPoint(x: 512, y: 370), radius: 88, alpha: 0.94)
sparkle(center: NSPoint(x: 650, y: 300), radius: 30, alpha: 0.58)
sparkle(center: NSPoint(x: 380, y: 298), radius: 18, alpha: 0.42)

// Inner rim highlight.
NSColor.white.withAlphaComponent(0.10).setStroke()
let innerRim = NSBezierPath(roundedRect: NSRect(x: 58, y: 58, width: 908, height: 908), xRadius: 196, yRadius: 196)
innerRim.lineWidth = 2
innerRim.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon")
}
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
