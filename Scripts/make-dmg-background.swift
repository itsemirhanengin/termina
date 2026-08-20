#!/usr/bin/env swift
import AppKit
import SwiftUI

// Renders the installer window's backdrop.
//
//   swift Scripts/make-dmg-background.swift
//
// Writes Design/dmg-background.png and @2x. Scripts/package.sh combines them
// into the multi-resolution TIFF that Finder needs, otherwise the window looks
// soft on a Retina display.
//
// The layout has to agree with the icon positions in package.sh: the app sits
// at (170, 200) and the Applications link at (470, 200), in Finder's
// top-left-origin window coordinates.

let width: CGFloat = 640
let height: CGFloat = 400
let appSlot = CGPoint(x: 170, y: 200)
let applicationsSlot = CGPoint(x: 470, y: 200)

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = root.appendingPathComponent("Design")

func hex(_ value: UInt32, _ alpha: Double = 1) -> Color {
    Color(
        .sRGB,
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255,
        opacity: alpha
    )
}

private let brand: UInt32 = 0xE8483F

struct BackdropView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [hex(0x232425), hex(0x141515)],
                startPoint: .top, endPoint: .bottom
            )

            // A pool of brand colour under the app, so the eye starts on the
            // thing being dragged rather than on the folder.
            RadialGradient(
                colors: [hex(brand, 0.16), hex(brand, 0)],
                center: .init(x: appSlot.x / width, y: appSlot.y / height),
                startRadius: 0,
                endRadius: 190
            )

            VStack(spacing: 0) {
                header
                Spacer()
                footer
            }

            Arrow()
                .stroke(hex(brand, 0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 96, height: 22)
                .position(
                    x: (appSlot.x + applicationsSlot.x) / 2,
                    y: appSlot.y
                )
        }
        .frame(width: width, height: height)
    }

    private var header: some View {
        VStack(spacing: 5) {
            Text("Termina")
                .font(.system(size: 30, weight: .semibold, design: .default))
                .foregroundStyle(.white)
            Text("A terminal built around projects")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(.top, 44)
    }

    private var footer: some View {
        Text("Drag Termina onto Applications")
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.32))
            .padding(.bottom, 26)
    }
}

/// A plain horizontal arrow: shaft plus a chevron head.
struct Arrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let headLength = rect.height * 0.55

        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))

        path.move(to: CGPoint(x: rect.maxX - headLength, y: midY - rect.height / 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX - headLength, y: midY + rect.height / 2))
        return path
    }
}

@MainActor
func render(scale: CGFloat) -> Data {
    let renderer = ImageRenderer(content: BackdropView())
    renderer.scale = scale
    renderer.isOpaque = true
    guard let image = renderer.cgImage else {
        FileHandle.standardError.write("render failed\n".data(using: .utf8)!)
        exit(1)
    }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try MainActor.assumeIsolated {
    try render(scale: 1).write(to: outputDirectory.appendingPathComponent("dmg-background.png"))
    try render(scale: 2).write(to: outputDirectory.appendingPathComponent("dmg-background@2x.png"))
}
print("wrote Design/dmg-background.png and @2x")
