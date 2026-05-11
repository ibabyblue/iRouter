import SwiftUI
import iRouter

// MARK: - Scene

struct FilterDemoView: View {
    @State private var router = IRouter<AppRoute>(
        root: .home,
        filters: [
            IRouterFilter { route, _ in
                if case .settings = route, !AuthState.shared.isLoggedIn {
                    return .redirect(.login, .sheet)
                }
                return .allow
            }
        ]
    )

    var body: some View {
        IRouterView(router: router) { route in
            switch route {
            case .home:     FilterHomeView()
            case .settings: FilterSettingsView()
            case .login:    FilterLoginView()
            default:        EmptyView()
            }
        }
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Views

private struct FilterHomeView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Button("Push Settings") {
                router.push(.settings)       // redirects to login sheet when not logged in
            }
        }
        .navigationTitle("Home")
    }
}

private struct FilterSettingsView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Text("Logged in ✓")
            Button("Logout") {
                AuthState.shared.isLoggedIn = false
                router.popToRoot()
            }
        }
        .navigationTitle("Settings")
    }
}

private struct FilterLoginView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        VStack(spacing: 24) {
            Text("Login Required")
                .font(.title2)
            Button("Login") {
                AuthState.shared.isLoggedIn = true
                router.dismissAndPush(.settings)
            }
            Button("Cancel") { router.dismiss() }
        }
        .navigationTitle("Login")
    }
}
