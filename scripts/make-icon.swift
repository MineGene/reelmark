// Draws Reelmark's app icon and writes every size the asset catalog needs.
// The icon is drawn in code, so it can be reviewed, changed and rebuilt
// from source like everything else. Run on a Mac (Command Line Tools are
// enough) after changing the drawing:
//
//   swift scripts/make-icon.swift
//
// The output is deterministic: the same script gives byte-identical PNGs.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: "Reelmark/Assets.xcassets/AppIcon.appiconset")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Draws the icon on Apple's 1024-point macOS grid: an 824-point rounded
/// square, centred, with a soft shadow. y points up.
func drawIcon(in ctx: CGContext) {
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Background: deep blue, lighter at the top.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, 0.3))
    ctx.addPath(shape)
    ctx.setFillColor(color(0x1E3A8A))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0x3B82F6), color(0x1E3A8A)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // A film reel: a white disc with five round windows and a hub.
    let centre = CGPoint(x: 492, y: 492)
    let reel = CGMutablePath()
    reel.addEllipse(in: CGRect(x: centre.x - 270, y: centre.y - 270, width: 540, height: 540))
    for i in 0..<5 {
        let angle = CGFloat(i) * 2 * .pi / 5 + .pi / 2
        let hole = CGPoint(x: centre.x + 160 * cos(angle), y: centre.y + 160 * sin(angle))
        reel.addEllipse(in: CGRect(x: hole.x - 72, y: hole.y - 72, width: 144, height: 144))
    }
    reel.addEllipse(in: CGRect(x: centre.x - 28, y: centre.y - 28, width: 56, height: 56))
    ctx.addPath(reel)
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath(using: .evenOdd)

    // A bookmark ribbon hanging over the reel's top-right edge: the "mark".
    let ribbon = CGMutablePath()
    let left: CGFloat = 626, right: CGFloat = 770, top: CGFloat = 860, bottom: CGFloat = 560
    ribbon.move(to: CGPoint(x: left, y: top))
    ribbon.addLine(to: CGPoint(x: right, y: top))
    ribbon.addLine(to: CGPoint(x: right, y: bottom))
    ribbon.addLine(to: CGPoint(x: (left + right) / 2, y: bottom + 56))
    ribbon.addLine(to: CGPoint(x: left, y: bottom))
    ribbon.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: color(0x000000, 0.25))
    ctx.addPath(ribbon)
    ctx.setFillColor(color(0xF59E0B))
    ctx.fillPath()
    ctx.restoreGState()
}

func writePNG(pixels: Int, to url: URL) {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(in: ctx)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("Couldn't write \(url.path)") }
}

// The sizes macOS asks for: 16 to 512 points, each at 1x and 2x.
var images: [String] = []
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        writePNG(pixels: points * scale, to: output.appending(path: name))
        images.append(
            """
                { "filename" : "\(name)", "idiom" : "mac", "scale" : "\(scale)x", "size" : "\(points)x\(points)" }
            """)
    }
}
let contents = """
    {
      "images" : [
    \(images.joined(separator: ",\n"))
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }

    """
try contents.write(to: output.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
try """
{
  "info" : { "author" : "xcode", "version" : 1 }
}

""".write(
    to: output.deletingLastPathComponent().appending(path: "Contents.json"), atomically: true,
    encoding: .utf8)
print("Wrote \(images.count) icon sizes to \(output.path)")
