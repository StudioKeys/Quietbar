import AppKit
import HeadphoneKit
import SwiftUI

struct MenuContentView: View {
    let activeDevice: ActiveDevice

    private var viewModel: HeadphoneViewModel { activeDevice.viewModel }
    @State private var isShowingSettings = false
    @State private var contentHeight: CGFloat = 400

    // Keep the panel inside the visible screen, leaving room for the menu bar, header padding and footer.
    private static var maximumControlsHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) - 110
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isShowingSettings {
                SettingsPanel { isShowingSettings = false }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ScrollView(.vertical) {
                    controls
                        .onGeometryChange(for: CGFloat.self) {
                            $0.size.height
                        } action: {
                            contentHeight = $0
                        }
                }
                .scrollIndicators(.automatic)
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(contentHeight, Self.maximumControlsHeight))
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            ConnectionFooter(viewModel: viewModel, isShowingSettings: $isShowingSettings)
        }
        .padding(14)
        .frame(width: 340)
        .animation(.easeOut(duration: 0.18), value: viewModel.snapshot)
        .animation(.easeOut(duration: 0.18), value: isShowingSettings)
        .onAppear { viewModel.menuOpened() }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeaderView(activeDevice: activeDevice)
            if viewModel.showsControls {
                ForEach(viewModel.sections) { section in
                    SectionCard(title: section.title) {
                        ForEach(section.settings.filter { $0.kind != .toggle && !$0.isDial }, id: \.id) {
                            descriptor in
                            SettingRow(descriptor: descriptor, viewModel: viewModel)
                        }
                        let dials = section.settings.filter(\.isDial)
                        if !dials.isEmpty {
                            EQDial(descriptors: dials, viewModel: viewModel)
                        }
                        let toggles = section.settings.filter { $0.kind == .toggle }
                        if !toggles.isEmpty {
                            ToggleTileGrid(descriptors: toggles, viewModel: viewModel)
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
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}
