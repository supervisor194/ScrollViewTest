import SwiftUI

@main
struct ScrollViewTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(N: 5, count: 100, cellWidth: 55.0)
        }
    }
}
