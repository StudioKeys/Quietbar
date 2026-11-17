import JBLProtocol
import SwiftUI

struct NoiseModeSection: View {
    let viewModel: HeadphoneViewModel
    @State private var ambientDraft = Double(AmbientLevel.range.upperBound)

    private var mode: Binding<NoiseMode?> {
        Binding(
            get: { viewModel.state.noiseMode },
            set: { newValue in
                if let newValue { viewModel.select(newValue) }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Noise control", selection: mode) {
                ForEach(NoiseMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(Optional(mode))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(viewModel.pending.contains(.noiseMode))
            .accessibilityLabel("Noise control")

            if viewModel.state.noiseMode == .ambientAware {
                ambientSlider
            }
        }
    }

    private var ambientSlider: some View {
        HStack {
            Text("Ambient level")
            Slider(
                value: $ambientDraft,
                in: Double(AmbientLevel.range.lowerBound)...Double(AmbientLevel.range.upperBound),
                step: 1
            ) { isEditing in
                if !isEditing { viewModel.setAmbientLevel(Int(ambientDraft)) }
            }
            .disabled(viewModel.pending.contains(.ambientLevel))
            .accessibilityLabel("Ambient Aware level")
            Text("\(Int(ambientDraft))").monospacedDigit().frame(width: 18)
        }
        .onChange(of: viewModel.state.ambientLevel, initial: true) { _, level in
            if let level { ambientDraft = Double(level.value) }
        }
    }
}

extension NoiseMode {
    var title: String {
        switch self {
        case .anc: "ANC"
        case .ambientAware: "Ambient"
        case .talkThru: "Talk-Thru"
        case .off: "Off"
        }
    }
}
