import HeadphoneKit
import SwiftUI

struct MenuContentView: View {
    let viewModel: HeadphoneViewModel
    @State private var isShowingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isShowingSettings {
                SettingsPanel { isShowingSettings = false }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                controls
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            ConnectionFooter(viewModel: viewModel, isShowingSettings: $isShowingSettings)
        }
        .padding(14)
        .frame(width: 340)
        .animation(.smooth(duration: 0.25), value: viewModel.snapshot)
        .animation(.snappy(duration: 0.3), value: isShowingSettings)
        .onAppear { viewModel.menuOpened() }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeaderView(viewModel: viewModel)
            if viewModel.showsControls {
                ForEach(viewModel.sections) { section in
                    SectionCard(title: section.title) {
                        ForEach(section.settings, id: \.id) { descriptor in
                            SettingRow(descriptor: descriptor, viewModel: viewModel)
                        }
                    }
                }
                if let error = viewModel.snapshot.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}
