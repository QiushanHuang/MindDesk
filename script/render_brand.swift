import AppKit
import Foundation

// Reproducible raster companion to docs/brand/minddesk-logo.svg.
// Usage: swift script/render_brand.swift OUTPUT.png [SIZE]
let output = CommandLine.arguments[1]
let size = Int(CommandLine.arguments.dropFirst(2).first ?? "1024")!
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let cg = context.cgContext
cg.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
cg.translateBy(x: 0, y: 1024)
cg.scaleBy(x: 1, y: -1)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
    CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}
let navy = color(19, 45, 70), paper = color(243, 245, 238), mint = color(112, 215, 199)
func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ fill: CGColor) {
    cg.setFillColor(fill)
    cg.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil))
    cg.fillPath()
}
func line(_ points: [(CGFloat, CGFloat)], _ width: CGFloat, _ stroke: CGColor) {
    cg.setStrokeColor(stroke); cg.setLineWidth(width)
    cg.setLineCap(.round); cg.setLineJoin(.round)
    cg.beginPath()
    cg.move(to: CGPoint(x: points[0].0, y: points[0].1))
    for p in points.dropFirst() { cg.addLine(to: CGPoint(x: p.0, y: p.1)) }
    cg.strokePath()
}
box(48, 48, 928, 928, 216, navy)
line([(278,382),(512,600),(746,382)], 42, mint)
box(166,226,224,286,42,paper); box(634,226,224,286,42,paper)
box(384,500,256,230,42,mint)
for (x,y,w) in [(220.0,302.0,100.0),(220,354,72),(688,302,100),(688,354,72)] {
    line([(x,y),(x+w,y)],20,navy)
}
line([(446,612),(490,650),(574,568)],24,navy)
line([(260,812),(764,812)],24,paper)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
