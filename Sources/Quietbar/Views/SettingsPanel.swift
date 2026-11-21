import SwiftUI

struct SettingsPanel: View {
    let onClose: () -> Void
    @AppStorage(GlassPreference.key) private var isGlassEnabled = true
    @AppStorage(MenuBarIconStyle.key) private var menuBarIconStyle = MenuBarIconStyle.product

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: onClose) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)
                Spacer()
                Text("Settings").font(.headline)
                Spacer()
                Color.clear.frame(width: 44, height: 1)
            }
            SectionCard(title: "Appearance") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Liquid Glass effects")
                        Text("Translucent, refracting cards and controls. Off uses solid backgrounds.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("Liquid Glass effects", isOn: $isGlassEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Menu bar icon")
                        Spacer()
                        Picker("Menu bar icon", selection: $menuBarIconStyle) {
                            ForEach(MenuBarIconStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .labelsHidden()
                        .fixedSize()
                    }
                    Text(
                        "For headphones with product artwork, such as CMF Headphone Pro. "
                            + "Noise mode shows the active mode while connected."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
