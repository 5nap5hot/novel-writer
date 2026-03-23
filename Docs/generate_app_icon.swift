import AppKit
import CoreGraphics
import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let docsDirectory = scriptURL.deletingLastPathComponent()
let projectRoot = docsDirectory.deletingLastPathComponent()
let outputDir = projectRoot
    .appendingPathComponent("Novel Writer Native", isDirectory: true)
    .appendingPathComponent("Assets.xcassets", isDirectory: true)
    .appendingPathComponent("AppIcon.appiconset", isDirectory: true)

let iconSpecs: [(name: String, pixels: Int)] = [
    ("appicon_16.png", 16),
    ("appicon_32.png", 32),
    ("appicon_64.png", 64),
    ("appicon_128.png", 128),
    ("appicon_128@2x.png", 256),
    ("appicon_256.png", 256),
    ("appicon_256@2x.png", 512),
    ("appicon_512.png", 512),
    ("appicon_512@2x.png", 1024)
]

func color(_ hex: Int, alpha: CGFloat = 1.0) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xff) / 255.0
    let g = CGFloat((hex >> 8) & 0xff) / 255.0
    let b = CGFloat(hex & 0xff) / 255.0
    return NSColor(red: r, green: g, blue: b, alpha: alpha)
}

func drawRoundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawIcon(in rect: NSRect) {
    let size = rect.width

    let bgTop = color(0x4A352B)
    let bgBottom = color(0x241915)
    let border = color(0x8C6249, alpha: 0.9)
    let glow = color(0xFFF9F0, alpha: 0.06)

    let parchment = color(0xFFF4E3)
    let parchmentShade = color(0xE8D2B8)
    let parchmentShadow = color(0xC8AE92, alpha: 0.75)
    let ruledLine = color(0xD0B79F, alpha: 0.85)

    let accent = color(0x9E4F2D)
    let accentStrong = color(0x7B3F25)
    let accentSoft = color(0xE2C3AA)
    let inkDark = color(0x221814)
    let inkHighlight = color(0x4F3B31)
    let feather = color(0xF2E2CB)
    let featherShade = color(0xC9AE91)

    let outerRect = rect.insetBy(dx: size * 0.015, dy: size * 0.015)
    let outerRadius = size * 0.23
    let outerPath = drawRoundedRect(outerRect, radius: outerRadius)
    NSGradient(colors: [bgTop, bgBottom])?.draw(in: outerPath, angle: -90)
    border.setStroke()
    outerPath.lineWidth = max(1.0, size * 0.018)
    outerPath.stroke()

    let innerGlowRect = rect.insetBy(dx: size * 0.05, dy: size * 0.05)
    let innerGlowPath = drawRoundedRect(innerGlowRect, radius: size * 0.18)
    glow.setFill()
    innerGlowPath.fill()

    let parchmentRect = NSRect(
        x: size * 0.23,
        y: size * 0.19,
        width: size * 0.56,
        height: size * 0.64
    )

    NSGraphicsContext.saveGraphicsState()
    let paperShadow = NSShadow()
    paperShadow.shadowBlurRadius = size * 0.06
    paperShadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
    paperShadow.shadowColor = parchmentShadow.withAlphaComponent(0.32)
    paperShadow.set()

    let context = NSGraphicsContext.current?.cgContext
    context?.translateBy(x: parchmentRect.midX, y: parchmentRect.midY)
    context?.rotate(by: -.pi / 30)
    context?.translateBy(x: -parchmentRect.midX, y: -parchmentRect.midY)

    let paperPath = drawRoundedRect(parchmentRect, radius: size * 0.08)
    NSGradient(colors: [parchment, parchmentShade])?.draw(in: paperPath, angle: -80)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    context?.translateBy(x: parchmentRect.midX, y: parchmentRect.midY)
    context?.rotate(by: -.pi / 30)
    context?.translateBy(x: -parchmentRect.midX, y: -parchmentRect.midY)
    let paperStroke = drawRoundedRect(parchmentRect, radius: size * 0.08)
    color(0xFFFDF8, alpha: 0.68).setStroke()
    paperStroke.lineWidth = max(1.0, size * 0.012)
    paperStroke.stroke()

    let insetRect = parchmentRect.insetBy(dx: size * 0.03, dy: size * 0.034)
    let insetPath = drawRoundedRect(insetRect, radius: size * 0.05)
    color(0xFFFFFF, alpha: 0.23).setStroke()
    insetPath.lineWidth = max(1.0, size * 0.007)
    insetPath.stroke()

    let lineWidth = max(1.0, size * 0.010)
    for offset in [0.26, 0.40, 0.54] {
        let y = parchmentRect.minY + parchmentRect.height * offset
        let linePath = NSBezierPath()
        linePath.move(to: NSPoint(x: parchmentRect.minX + parchmentRect.width * 0.13, y: y))
        linePath.line(to: NSPoint(x: parchmentRect.maxX - parchmentRect.width * 0.12, y: y))
        ruledLine.setStroke()
        linePath.lineWidth = lineWidth
        linePath.lineCapStyle = .round
        linePath.stroke()
    }

    let cornerFold = NSBezierPath()
    cornerFold.move(to: NSPoint(x: parchmentRect.maxX - parchmentRect.width * 0.20, y: parchmentRect.maxY))
    cornerFold.line(to: NSPoint(x: parchmentRect.maxX, y: parchmentRect.maxY))
    cornerFold.line(to: NSPoint(x: parchmentRect.maxX, y: parchmentRect.maxY - parchmentRect.height * 0.18))
    cornerFold.close()
    color(0xF4E2CB, alpha: 0.95).setFill()
    cornerFold.fill()

    let foldLine = NSBezierPath()
    foldLine.move(to: NSPoint(x: parchmentRect.maxX - parchmentRect.width * 0.20, y: parchmentRect.maxY))
    foldLine.line(to: NSPoint(x: parchmentRect.maxX, y: parchmentRect.maxY - parchmentRect.height * 0.18))
    parchmentShade.setStroke()
    foldLine.lineWidth = max(1.0, size * 0.006)
    foldLine.stroke()
    NSGraphicsContext.restoreGraphicsState()

    let bottleRect = NSRect(
        x: size * 0.17,
        y: size * 0.18,
        width: size * 0.22,
        height: size * 0.29
    )
    let bottleBody = drawRoundedRect(bottleRect, radius: size * 0.05)
    NSGraphicsContext.saveGraphicsState()
    let bottleShadow = NSShadow()
    bottleShadow.shadowBlurRadius = size * 0.04
    bottleShadow.shadowOffset = NSSize(width: 0, height: -size * 0.01)
    bottleShadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    bottleShadow.set()
    NSGradient(colors: [inkHighlight, inkDark])?.draw(in: bottleBody, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let bottleNeckRect = NSRect(
        x: bottleRect.minX + bottleRect.width * 0.31,
        y: bottleRect.maxY - bottleRect.height * 0.02,
        width: bottleRect.width * 0.38,
        height: bottleRect.height * 0.26
    )
    let bottleNeck = drawRoundedRect(bottleNeckRect, radius: size * 0.02)
    NSGradient(colors: [accentStrong, accent])?.draw(in: bottleNeck, angle: -90)

    let bottleLipRect = NSRect(
        x: bottleNeckRect.minX - bottleRect.width * 0.03,
        y: bottleNeckRect.maxY - bottleRect.height * 0.06,
        width: bottleNeckRect.width + bottleRect.width * 0.06,
        height: bottleRect.height * 0.08
    )
    let bottleLip = drawRoundedRect(bottleLipRect, radius: size * 0.025)
    accentSoft.setFill()
    bottleLip.fill()

    let bottleHighlight = NSBezierPath()
    bottleHighlight.move(to: NSPoint(x: bottleRect.minX + bottleRect.width * 0.28, y: bottleRect.minY + bottleRect.height * 0.18))
    bottleHighlight.curve(
        to: NSPoint(x: bottleRect.minX + bottleRect.width * 0.34, y: bottleRect.maxY - bottleRect.height * 0.18),
        controlPoint1: NSPoint(x: bottleRect.minX + bottleRect.width * 0.22, y: bottleRect.minY + bottleRect.height * 0.44),
        controlPoint2: NSPoint(x: bottleRect.minX + bottleRect.width * 0.26, y: bottleRect.maxY - bottleRect.height * 0.30)
    )
    color(0xFFF7EF, alpha: 0.24).setStroke()
    bottleHighlight.lineWidth = max(1.0, size * 0.012)
    bottleHighlight.lineCapStyle = .round
    bottleHighlight.stroke()

    let quillStart = NSPoint(x: size * 0.36, y: size * 0.24)
    let quillEnd = NSPoint(x: size * 0.76, y: size * 0.73)
    let shaft = NSBezierPath()
    shaft.move(to: quillStart)
    shaft.curve(
        to: quillEnd,
        controlPoint1: NSPoint(x: size * 0.48, y: size * 0.37),
        controlPoint2: NSPoint(x: size * 0.62, y: size * 0.60)
    )
    accentStrong.setStroke()
    shaft.lineWidth = max(1.2, size * 0.020)
    shaft.lineCapStyle = .round
    shaft.stroke()

    let featherShape = NSBezierPath()
    featherShape.move(to: NSPoint(x: size * 0.42, y: size * 0.34))
    featherShape.curve(
        to: NSPoint(x: size * 0.78, y: size * 0.72),
        controlPoint1: NSPoint(x: size * 0.54, y: size * 0.48),
        controlPoint2: NSPoint(x: size * 0.68, y: size * 0.69)
    )
    featherShape.curve(
        to: NSPoint(x: size * 0.60, y: size * 0.82),
        controlPoint1: NSPoint(x: size * 0.81, y: size * 0.77),
        controlPoint2: NSPoint(x: size * 0.69, y: size * 0.86)
    )
    featherShape.curve(
        to: NSPoint(x: size * 0.38, y: size * 0.40),
        controlPoint1: NSPoint(x: size * 0.50, y: size * 0.78),
        controlPoint2: NSPoint(x: size * 0.35, y: size * 0.52)
    )
    featherShape.close()

    NSGraphicsContext.saveGraphicsState()
    let featherShadow = NSShadow()
    featherShadow.shadowBlurRadius = size * 0.03
    featherShadow.shadowOffset = NSSize(width: 0, height: -size * 0.008)
    featherShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    featherShadow.set()
    NSGradient(colors: [feather, featherShade])?.draw(in: featherShape, angle: -35)
    NSGraphicsContext.restoreGraphicsState()

    let spine = NSBezierPath()
    spine.move(to: NSPoint(x: size * 0.44, y: size * 0.36))
    spine.curve(
        to: NSPoint(x: size * 0.73, y: size * 0.75),
        controlPoint1: NSPoint(x: size * 0.54, y: size * 0.50),
        controlPoint2: NSPoint(x: size * 0.66, y: size * 0.66)
    )
    accent.withAlphaComponent(0.85).setStroke()
    spine.lineWidth = max(1.0, size * 0.010)
    spine.stroke()

    for index in 0..<4 {
        let t = CGFloat(index) / 4.0
        let x = size * (0.50 + 0.07 * t)
        let y = size * (0.48 + 0.09 * t)
        let barb = NSBezierPath()
        barb.move(to: NSPoint(x: x, y: y))
        barb.line(to: NSPoint(x: x - size * (0.09 - 0.012 * t), y: y + size * (0.08 - 0.008 * t)))
        color(0xFFF7EE, alpha: 0.74).setStroke()
        barb.lineWidth = max(1.0, size * 0.006)
        barb.stroke()
    }

    let nib = NSBezierPath()
    nib.move(to: quillStart)
    nib.line(to: NSPoint(x: quillStart.x - size * 0.024, y: quillStart.y - size * 0.046))
    nib.line(to: NSPoint(x: quillStart.x + size * 0.034, y: quillStart.y - size * 0.020))
    nib.close()
    accent.setFill()
    nib.fill()

    let nibCut = NSBezierPath()
    nibCut.move(to: NSPoint(x: quillStart.x + size * 0.010, y: quillStart.y - size * 0.008))
    nibCut.line(to: NSPoint(x: quillStart.x + size * 0.002, y: quillStart.y - size * 0.030))
    color(0xF6E6D6, alpha: 0.7).setStroke()
    nibCut.lineWidth = max(1.0, size * 0.004)
    nibCut.stroke()
}

let fileManager = FileManager.default
try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

for spec in iconSpecs {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: spec.pixels,
        pixelsHigh: spec.pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        continue
    }

    rep.size = NSSize(width: spec.pixels, height: spec.pixels)
    NSGraphicsContext.saveGraphicsState()
    if let context = NSGraphicsContext(bitmapImageRep: rep) {
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        color(0x000000, alpha: 0).setFill()
        NSRect(x: 0, y: 0, width: spec.pixels, height: spec.pixels).fill()
        drawIcon(in: NSRect(x: 0, y: 0, width: spec.pixels, height: spec.pixels))
        context.flushGraphics()
    }
    NSGraphicsContext.restoreGraphicsState()

    if let png = rep.representation(using: .png, properties: [:]) {
        try png.write(to: outputDir.appendingPathComponent(spec.name))
    }
}
