import SwiftUI
import iRouter

// MARK: - Route

enum AppRoute: Hashable, Sendable {
    case home
    case detail(id: String)
    case settings
    case login
    case feed
}

// MARK: - Auth (demo-only singleton)

final class AuthState {
    static let shared = AuthState()
    var isLoggedIn = false
    private init() {}
}

// MARK: - Demo menu

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Basic Navigation") { BasicDemoView() }
                NavigationLink("Filter / Auth Guard")  { FilterDemoView() }
                NavigationLink("Flush Mode")           { FlushDemoView() }
                NavigationLink("Multi-Tab Routers")    { TabDemoView() }
            }
            .navigationTitle("iRouter Demo")
        }
    }
}
