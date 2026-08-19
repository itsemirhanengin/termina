import AppKit
import SwiftUI

/// Termina's primary colour. The same value lives in the `AccentColor` asset
/// so AppKit-drawn controls and the app icon's tile agree with SwiftUI.
enum Brand {
    static let primaryHex = "#E8483F"

    static let primaryNSColor = NSColor(hex: primaryHex)
    static let primary = Color(nsColor: primaryNSColor)
}
