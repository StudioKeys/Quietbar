import JBLProtocol
import SwiftUI

struct SpatialSection: View {
    let viewModel: HeadphoneViewModel

    private var spatial: SpatialSetting? { viewModel.state.spatial }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Spatial Sound", isOn: isOn)
                    .disabled(spatial == nil || viewModel.pending.contains(.spatial))
                Picker("Spatial mode", selection: mode) {
                    ForEach(SpatialMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(spatial?.isOn != true || viewModel.pending.contains(.spatial))
                .accessibilityLabel("Spatial Sound mode")
            }
            Toggle("Low Volume EQ", isOn: lowVolumeEq)
                .disabled(viewModel.state.lowVolumeEq == nil || viewModel.pending.contains(.lowVolumeEq))
        }
    }

    private var isOn: Binding<Bool> {
        Binding(
            get: { spatial?.isOn ?? false },
            set: { newValue in
                viewModel.setSpatial(SpatialSetting(isOn: newValue, mode: spatial?.mode ?? .music))
            }
        )
    }

    private var mode: Binding<SpatialMode> {
        Binding(
            get: { spatial?.mode ?? .music },
            set: { newValue in viewModel.setSpatial(SpatialSetting(isOn: true, mode: newValue)) }
        )
    }

    private var lowVolumeEq: Binding<Bool> {
        Binding(
            get: { viewModel.state.lowVolumeEq ?? false },
            set: { newValue in viewModel.setLowVolumeEq(newValue) }
        )
    }
}

extension SpatialMode {
    var title: String {
        switch self {
        case .music: "Music"
        case .movie: "Movie"
        case .game: "Game"
        }
    }
}
