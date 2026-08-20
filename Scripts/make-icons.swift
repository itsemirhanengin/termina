#!/usr/bin/env swift
import AppKit
import SwiftUI

// Regenerates both app icon sets from Design/icon-source.png.
//
//   swift Scripts/make-icons.swift
//
// Writes Sources/Assets.xcassets/AppIcon.appiconset (release) and
// AppIcon-Dev.appiconset (a blueprint of the same mark). Debug builds point at
// the second one, which is how an app shows a distinct development icon —
// macOS does not badge development builds by itself.

// MARK: - Layout
//
// Apple's icon grid: an 824pt tile centred in a 1024pt canvas, the margin left
// for the artwork's own shadow.

let canvas: CGFloat = 1024
let tile: CGFloat = 824
let corner: CGFloat = 185.4          // 22.37% of the tile
let markWidth: CGFloat = 470

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("Design/icon-source.png")
/// Loaded as a vector, so it stays sharp when drawn at tile size.
let blueprintURL = root.appendingPathComponent("Design/blueprint-background.svg")
let assetsURL = root.appendingPathComponent("Sources/Assets.xcassets")

func hex(_ value: UInt32, _ alpha: Double = 1) -> Color {
    Color(
        .sRGB,
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255,
        opacity: alpha
    )
}

enum IconStyle {
    case release
    /// A technical drawing of the same mark: grid paper, dimension lines, and
    /// the shape rendered as if it were being specified rather than shipped.
    case blueprint
}

// MARK: - Source artwork

struct Mark {
    let image: NSImage
    let size: CGSize
}

/// Loads the mark cropped to its own bounds, so the icon grid — not the source
/// file's padding — decides how big it sits on the tile.
///
/// `knockOutLightParts` turns the solid mark into a white silhouette with its
/// eyes punched through to transparency, which is what lets the blueprint grid
/// show through them.
func loadMark(at url: URL, knockOutLightParts: Bool) -> Mark {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        FileHandle.standardError.write("cannot read \(url.path)\n".data(using: .utf8)!)
        exit(1)
    }

    let width = image.width, height = image.height
    var buffer = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(
        data: &buffer, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var minX = width, minY = height, maxX = 0, maxY = 0
    for y in 0..<height {
        for x in 0..<width where buffer[(y * width + x) * 4 + 3] > 10 {
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }
        }
    }

    if knockOutLightParts {
        for index in stride(from: 0, to: buffer.count, by: 4) {
            let alpha = buffer[index + 3]
            guard alpha > 0 else { continue }
            // Premultiplied, so compare against the alpha to find the light
            // areas — those are the eyes.
            let isLight = buffer[index] > alpha / 2 && buffer[index + 1] > alpha / 2
                && buffer[index + 2] > alpha / 2
            if isLight {
                buffer[index] = 0; buffer[index + 1] = 0
                buffer[index + 2] = 0; buffer[index + 3] = 0
            } else {
                buffer[index] = alpha; buffer[index + 1] = alpha; buffer[index + 2] = alpha
            }
        }
    }

    guard let redrawn = context.makeImage() else { exit(1) }
    let rect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    let cropped = redrawn.cropping(to: rect)!
    let size = NSSize(width: rect.width, height: rect.height)
    return Mark(image: NSImage(cgImage: cropped, size: size), size: size)
}

/// `NSImage` reads SVG natively, so this scales to tile size without ever
/// being rasterised at the source file's 128pt.
let blueprintBackground: NSImage = {
    guard let image = NSImage(contentsOf: blueprintURL) else {
        FileHandle.standardError.write("cannot read \(blueprintURL.path)\n".data(using: .utf8)!)
        exit(1)
    }
    return image
}()

// MARK: - The icon

struct IconView: View {
    let mark: Mark
    let style: IconStyle

    /// The blueprint carries its own drawing, so the mark can sit larger on it.
    private var markSize: CGFloat { style == .blueprint ? 520 : markWidth }
    private var markHeight: CGFloat { markSize * (mark.size.height / mark.size.width) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        ZStack {
            background
                .overlay { rim(shape) }
                // Clipped before the shadow so everything follows the tile's
                // rounded corners instead of squaring them off.
                .clipShape(shape)
                .frame(width: tile, height: tile)
                .shadow(color: .black.opacity(0.34), radius: 22, x: 0, y: 16)

            Image(nsImage: mark.image)
                .resizable()
                .interpolation(.high)
                .frame(width: markSize, height: markHeight)
                .shadow(
                    color: .black.opacity(style == .blueprint ? 0.22 : 0.28),
                    radius: 14, x: 0, y: 9
                )
        }
        .frame(width: canvas, height: canvas)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .release:
            Rectangle()
                .fill(fill)
                .overlay { gloss }
        case .blueprint:
            // The artwork already carries its own grid, glow and edge shading;
            // adding another gloss layer on top only muddies it.
            Image(nsImage: blueprintBackground)
                .resizable()
                .interpolation(.high)
        }
    }

    private var fill: LinearGradient {
        LinearGradient(
            colors: [hex(0x37393A), hex(0x1B1C1C)],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Stands in for the system's glass material: a broad specular pool at the
    /// top left and a faint bounce along the bottom.
    private var gloss: some View {
        ZStack {
            EllipticalGradient(
                colors: [.white.opacity(style == .blueprint ? 0.42 : 0.18), .clear],
                center: .init(x: 0.32, y: -0.06),
                startRadiusFraction: 0,
                endRadiusFraction: 0.72
            )
            LinearGradient(
                colors: [.clear, .white.opacity(0.10)],
                startPoint: .center, endPoint: .bottom
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.18)],
                startPoint: .center, endPoint: .bottom
            )
        }
    }

    /// A single hairline of light along the top edge, the way a physical tile
    /// catches a window: keeps the flat fill from reading as a sticker.
    private func rim(_ shape: RoundedRectangle) -> some View {
        shape.strokeBorder(
            LinearGradient(
                colors: [
                    .white.opacity(style == .blueprint ? 0.55 : 0.16),
                    .white.opacity(0.02),
                    .white.opacity(style == .blueprint ? 0.22 : 0.0),
                ],
                startPoint: .top, endPoint: .bottom
            ),
            lineWidth: 2.5
        )
    }
}

// MARK: - Writing

/// macOS wants every one of these; sharing a file between two entries makes
/// `actool` drop sizes from the compiled icon.
let entries: [(name: String, size: Int, scale: String, pixels: Int)] = [
    ("icon_16x16", 16, "1x", 16),
    ("icon_16x16@2x", 16, "2x", 32),
    ("icon_32x32", 32, "1x", 32),
    ("icon_32x32@2x", 32, "2x", 64),
    ("icon_128x128", 128, "1x", 128),
    ("icon_128x128@2x", 128, "2x", 256),
    ("icon_256x256", 256, "1x", 256),
    ("icon_256x256@2x", 256, "2x", 512),
    ("icon_512x512", 512, "1x", 512),
    ("icon_512x512@2x", 512, "2x", 1024),
]

@MainActor
func renderMaster(mark: Mark, style: IconStyle) -> CGImage {
    let renderer = ImageRenderer(content: IconView(mark: mark, style: style))
    renderer.scale = 1
    renderer.isOpaque = false
    guard let image = renderer.cgImage else {
        FileHandle.standardError.write("render failed\n".data(using: .utf8)!)
        exit(1)
    }
    return image
}

func scaled(_ image: CGImage, to pixels: Int) -> Data {
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

func write(setName: String, style: IconStyle) throws {
    let directory = assetsURL.appendingPathComponent("\(setName).appiconset")
    try? FileManager.default.removeItem(at: directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let mark = loadMark(at: sourceURL, knockOutLightParts: style == .blueprint)
    let master = MainActor.assumeIsolated { renderMaster(mark: mark, style: style) }
    for entry in entries {
        try scaled(master, to: entry.pixels)
            .write(to: directory.appendingPathComponent("\(entry.name).png"))
    }

    let images = entries.map { entry in
        """
            { "filename" : "\(entry.name).png", "idiom" : "mac", "scale" : "\(entry.scale)", "size" : "\(entry.size)x\(entry.size)" }
        """
    }.joined(separator: ",\n")

    let contents = """
    {
      "images" : [
    \(images)
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }

    """
    try contents.write(
        to: directory.appendingPathComponent("Contents.json"),
        atomically: true,
        encoding: .utf8
    )
    print("wrote \(setName).appiconset")
}

try write(setName: "AppIcon", style: .release)
try write(setName: "AppIcon-Dev", style: .blueprint)
