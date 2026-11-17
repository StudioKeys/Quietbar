import SwiftUI

@main
struct QuietbarApp: App {
    var body: some Scene {
        MenuBarExtra("Quietbar", systemImage: "headphones") {
            EmptyView()
        }
    }
}
