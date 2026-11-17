import SwiftUI

enum GlassPreference {
    static let key = "liquidGlassEnabled"
}

struct CardBackground: ViewModifier {
    @AppStorage(GlassPreference.key) private var isGlassEnabled = true

    func body(content: Content) -> some View {
        if isGlassEnabled {
            content.glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content.background(.background.secondary, in: .rect(cornerRadius: 10))
        }
    }
}

extension View {
    func cardBackground() -> some View {
        modifier(CardBackground())
    }
}
