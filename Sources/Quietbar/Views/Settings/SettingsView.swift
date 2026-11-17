import SwiftUI

struct SettingsView: View {
    @AppStorage(GlassPreference.key) private var isGlassEnabled = true

    var body: some View {
        Form {
            Toggle(isOn: $isGlassEnabled) {
                Text("Liquid Glass effects")
                Text("Translucent, refracting cards and controls. Off uses solid backgrounds.")
            }
            .toggleStyle(.switch)
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }
}
