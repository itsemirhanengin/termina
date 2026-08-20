import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState = .shared

    /// Resolved once per settings window rather than on every body pass —
    /// enumerating font families touches the font database.
    private let monospacedFamilies = TerminalFont.monospacedFamilies()

    var body: some View {
        Form {
            Picker("Theme", selection: $state.activeThemeID) {
                ForEach(state.extensions.themes) { theme in
                    Text(theme.name).tag(theme.id)
                }
            }

            Picker("Font", selection: $state.fontFamily) {
                Text("System Mono").tag(TerminalFont.systemFamily)
                Divider()
                ForEach(monospacedFamilies, id: \.self) { family in
                    Text(family).tag(family)
                }
            }

            Slider(value: $state.fontSize, in: 10...20, step: 1) {
                Text("Font Size")
            } minimumValueLabel: {
                Text("10")
            } maximumValueLabel: {
                Text("20")
            }
            LabeledContent("Current Size", value: "\(Int(state.fontSize)) pt")
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize()
    }
}
