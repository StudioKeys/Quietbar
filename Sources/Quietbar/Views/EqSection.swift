import JBLProtocol
import SwiftUI

struct EqSection: View {
    let viewModel: HeadphoneViewModel

    private var preset: Binding<EqPreset?> {
        Binding(
            get: {
                guard case .preset(let preset) = viewModel.state.eq else { return nil }
                return preset
            },
            set: { newValue in
                if let newValue { viewModel.select(newValue) }
            }
        )
    }

    var body: some View {
        Picker("EQ", selection: preset) {
            if case .custom = viewModel.state.eq {
                Text("Custom").tag(EqPreset?.none)
            }
            ForEach(EqPreset.allCases, id: \.self) { preset in
                Text(preset.displayName).tag(Optional(preset))
            }
        }
        .pickerStyle(.menu)
        .disabled(viewModel.pending.contains(.eq) || viewModel.state.eq == nil)
        .accessibilityLabel("Equalizer preset")
    }
}
