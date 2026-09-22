#!/usr/bin/swift
import AppKit

func makeIcon(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

        let s = size
        let cs = CGColorSpaceCreateDeviceRGB()

        // Rounded rect clip
        let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                          cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
        ctx.addPath(path)
        ctx.clip()

        // Purple gradient background
        let colors = [CGColor(red: 0.45, green: 0.20, blue: 0.90, alpha: 1),
                      CGColor(red: 0.15, green: 0.05, blue: 0.45, alpha: 1)] as CFArray
        let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
        ctx.drawLinearGradient(gradient,
            start: CGPoint(x: s * 0.3, y: s),
            end:   CGPoint(x: s * 0.7, y: 0),
            options: [])

        // SF Symbol centered, tinted white
        let config = NSImage.SymbolConfiguration(pointSize: s * 0.52, weight: .medium)
        if let symbol = NSImage(systemSymbolName: "dot.radiowaves.left.and.right",
                                accessibilityDescription: nil)?
                        .withSymbolConfiguration(config) {
            // Tint to white using mask compositing
            let tinted = NSImage(size: symbol.size, flipped: false) { r in
                NSColor.white.withAlphaComponent(0.92).setFill()
                r.fill()
                symbol.draw(in: r, from: .zero, operation: .destinationIn, fraction: 1)
                return true
            }
            let x = (s - tinted.size.width)  / 2
            let y = (s - tinted.size.height) / 2
            tinted.draw(in: NSRect(x: x, y: y, width: tinted.size.width, height: tinted.size.height),
                        from: .zero, operation: .sourceOver, fraction: 1)
        }

        return true
    }
}

let iconsetPath = "PS5Streamer/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
var images: [[String: Any]] = []

for (size, scale) in sizes {
    let px       = size * scale
    let filename = "icon_\(size)x\(size)@\(scale)x.png"
    let img = makeIcon(size: CGFloat(px))
    if let tiff = img.tiffRepresentation,
       let rep  = NSBitmapImageRep(data: tiff),
       let png  = rep.representation(using: .png, properties: [:]) {
        try! png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(filename)"))
        print("✅ \(filename)")
    }
    images.append(["filename": filename, "idiom": "mac",
                   "scale": "\(scale)x", "size": "\(size)x\(size)"])
}

let json: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let data = try! JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
try! data.write(to: URL(fileURLWithPath: "\(iconsetPath)/Contents.json"))
print("🎉 Done")
