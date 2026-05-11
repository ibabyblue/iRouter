import SwiftUI
import iRouter

struct TabDemoView: View {
    @State private var tabARouter = IRouter<AppRoute>(root: .home)
    @State private var tabBRouter = IRouter<AppRoute>(root: .feed)

    var body: some View {
        TabView {
            IRouterView(router: tabARouter) { route in
                switch route {
                case .home:           TabHomeView(label: "Tab A")
                case .detail(let id): TabDetailView(id: id)
                default:              EmptyView()
                }
            }
            .tabItem { Label("Tab A", systemImage: "house") }

            IRouterView(router: tabBRouter) { route in
                switch route {
                case .feed:           TabFeedView()
                case .detail(let id): TabDetailView(id: id)
                default:              EmptyView()
                }
            }
            .tabItem { Label("Tab B", systemImage: "list.bullet") }
        }
    }
}

// MARK: - Views

private struct TabHomeView: View {
    let label: String
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Button("Push Detail") { router.push(.detail(id: "\(label)-1")) }
        }
        .navigationTitle(label)
    }
}

private struct TabFeedView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Text("This tab has its own independent router.")
            Button("Push Detail") { router.push(.detail(id: "feed-1")) }
        }
        .navigationTitle("Tab B")
    }
}

private struct TabDetailView: View {
    let id: String
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Button("Pop") { router.pop() }
            Button("Pop to Root") { router.popToRoot() }
        }
        .navigationTitle("Detail \(id)")
    }
}
