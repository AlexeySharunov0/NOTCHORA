#!/usr/bin/env swift
import AppKit
import Foundation

// NOTCHORA uses a strictly black-and-white icon: a white notch tile cut out of
// a black squircle. No colour, gradients, glows, or translucency.
let output = CommandLine.arguments.dropFirst().first ?? "build/icon-1024.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("No graphics context")
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

// Black squircle.
let outer = NSRect(x: 34, y: 34, width: 956, height: 956)
let outerPath = NSBezierPath(roundedRect: outer, xRadius: 218, yRadius: 218)
NSColor.black.setFill()
outerPath.fill()

// A restrained white rim is the only edge treatment.
NSColor.white.withAlphaComponent(0.22).setStroke()
outerPath.lineWidth = 5
outerPath.stroke()

// White mark with a real notch cut out of its top edge.
let markRect = NSRect(x: 246, y: 276, width: 532, height: 532)
let markPath = NSBezierPath(roundedRect: markRect, xRadius: 152, yRadius: 152)
let notchHole = NSBezierPath(roundedRect: NSRect(x: 402, y: 732, width: 220, height: 92), xRadius: 40, yRadius: 40)

let mask = NSBezierPath()
mask.windingRule = .evenOdd
mask.append(markPath)
mask.append(notchHole)

context.saveGState()
mask.addClip()
NSColor.white.setFill()
markRect.fill()
context.restoreGState()

// A black sparkle inside the white tile keeps the icon monochrome while
// retaining the NOTCHORA signature.
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
    NSColor.black.withAlphaComponent(alpha).setFill()
    path.fill()
}

sparkle(center: NSPoint(x: 512, y: 370), radius: 88, alpha: 0.94)
sparkle(center: NSPoint(x: 650, y: 300), radius: 30, alpha: 0.62)
sparkle(center: NSPoint(x: 380, y: 298), radius: 18, alpha: 0.46)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon")
}
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
