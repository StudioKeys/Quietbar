import HeadphoneKit
import SwiftUI

struct SettingsPanel: View {
    let onClose: () -> Void
    @AppStorage(GlassPreference.key) private var isGlassEnabled = true
    @AppStorage(ExperimentalWritePreference.key) private var experimentalWritesEnabled = false

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
            }
            SectionCard(title: "Experimental controls") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CMF Headphone Pro controls")
                            Text(
                                "Enable after confirming the current setting is safe to restore. "
                                    + "Codec switching, firmware and destructive operations remain unavailable."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Toggle("CMF Headphone Pro controls", isOn: $experimentalWritesEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                    }
                    if experimentalWritesEnabled {
                        Label("Experimental writes are enabled", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}
