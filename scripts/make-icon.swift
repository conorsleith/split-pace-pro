// Renders the 1024×1024 app icon: a white stopwatch on blue, matching the
// Android launcher icon. Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size = 1024
let out = CommandLine.arguments[1]

// App Store icons must be opaque, so draw into a context without alpha.
let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

// Blue background (#1A73E8).
context.setFillColor(CGColor(red: 0x1A / 255.0, green: 0x73 / 255.0, blue: 0xE8 / 255.0, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Same geometry as the Android vector (108-unit canvas), enlarged to fill
// more of the iOS icon and centred on the glyph (54, 54). Flipped because
// Core Graphics has its origin at the bottom left.
let scale = Double(size) / 72
let offset = Double(size) / 2 - 54 * scale
func x(_ v: Double) -> Double { v * scale + offset }
func y(_ v: Double) -> Double { Double(size) - (v * scale + offset) }

context.setFillColor(.white)
context.setStrokeColor(.white)

// Crown.
context.fill(CGRect(x: x(48), y: y(35), width: 12 * scale, height: 5 * scale))

// Dial.
context.setLineWidth(5 * scale)
context.strokeEllipse(in: CGRect(x: x(35), y: y(77), width: 38 * scale, height: 38 * scale))

// Hand.
context.setLineWidth(4 * scale)
context.setLineCap(.round)
context.move(to: CGPoint(x: x(54), y: y(58)))
context.addLine(to: CGPoint(x: x(54), y: y(46)))
context.strokePath()

let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
