import SwiftUI
import iRouter

// MARK: - Scene
// Simulates a push notification tap: opens a sheet, then taps "Notification" which
// calls flush: true — the sheet is dismissed automatically before navigating.

struct FlushDemoView: View {
    @State private var router = IRouter<AppRoute>(root: .home)

    var body: some View {
        IRouterView(router: router) { route in
            switch route {
            case .home:           FlushHomeView()
            case .detail(let id): FlushDetailView(id: id)
            default:              EmptyView()
            }
        }
        .navigationTitle("Flush")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Views

private struct FlushHomeView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Section {
                Button("Open Sheet") { router.sheet(.detail(id: "in-sheet")) }
            } header: {
                Text("Step 1 — open a sheet to simulate modal state")
            }
            Section {
                Button("Simulate Notification Tap") {
                    // flush: true dismisses any open modals before navigating
                    router.push(.detail(id: "from-notification"), flush: true)
                }
            } header: {
                Text("Step 2 — tap to navigate with flush, sheet closes automatically")
            }
        }
        .navigationTitle("Flush Demo")
    }
}

private struct FlushDetailView: View {
    let id: String
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        VStack(spacing: 16) {
            Text("Destination: \(id)")
                .font(.title2)
            Button("Dismiss / Pop") { router.dismiss() }
        }
        .navigationTitle("Detail")
    }
}
