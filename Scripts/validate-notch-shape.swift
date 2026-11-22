import AppKit
import Foundation

// Validates the notch surface in a QA screenshot:
// - its top edge is welded to the display edge;
// - it is horizontally centered while it grows and shrinks;
// - the surface edge is pure opaque black;
// - only the rounded lower corners are transparent.
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Notch shape validation failed: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 2 else {
    fail("usage: validate-notch-shape.swift <screenshot.png>")
}

guard let data = try? Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])),
      let rep = NSBitmapImageRep(data: data) else {
    fail("cannot decode PNG")
}

let width = rep.pixelsWide
let height = rep.pixelsHigh
guard width > 40, height > 40 else { fail("screenshot too small") }

func color(_ x: Int, _ y: Int) -> NSColor {
    guard let value = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
        fail("cannot read pixel \(x),\(y)")
    }
    return value
}

func alpha(_ x: Int, _ y: Int) -> CGFloat {
    color(x, y).alphaComponent
}

func isBlackOpaque(_ x: Int, _ y: Int) -> Bool {
    let c = color(x, y)
    return c.alphaComponent >= 0.995
        && c.redComponent <= 0.015
        && c.greenComponent <= 0.015
        && c.blueComponent <= 0.015
}

func isTransparent(_ x: Int, _ y: Int) -> Bool {
    alpha(x, y) <= 0.01
}

// Find the surface width on the welded top row.
var left = 0
while left < width && alpha(left, 2) <= 0.01 { left += 1 }
var right = width - 1
while right > left && alpha(right, 2) <= 0.01 { right -= 1 }
guard right - left > 20 else { fail("no surface found on the top edge") }

// Find the lower edge down the vertical center.
let centerX = (left + right) / 2
var bottom = height - 1
while bottom > 0 && alpha(centerX, bottom) <= 0.01 { bottom -= 1 }
guard bottom > 10 else { fail("no surface height found") }

let centerOffset = abs(CGFloat(centerX) - CGFloat(width) / 2)
guard centerOffset <= 2 else {
    fail("surface is not horizontally centered (offset \(centerOffset)px)")
}
guard isBlackOpaque(centerX, 1) else { fail("top center is not opaque black") }
guard alpha(centerX, bottom - 2) >= 0.995 else { fail("bottom center is not opaque") }

// The left edge of the surface, away from the rounded lower corner.
for y in stride(from: 6, through: max(8, bottom - 70), by: 4) where !isBlackOpaque(left + 1, y) {
    fail("left surface edge is not opaque black at y=\(y)")
}

// Both lower corners are cut away; the rectangle's corners are transparent.
if !isTransparent(left + 1, bottom - 1) || !isTransparent(right - 1, bottom - 1) {
    fail("lower corners are not rounded")
}

print("Notch shape OK: \(width)×\(height), surface \(left)...\(right)×0...\(bottom), opaque black, welded and centered, rounded bottom")
