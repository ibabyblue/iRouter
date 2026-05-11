import SwiftUI
import iRouter

// MARK: - Scene

struct BasicDemoView: View {
    @State private var router = IRouter<AppRoute>(root: .home)

    var body: some View {
        IRouterView(router: router) { route in
            switch route {
            case .home:           BasicHomeView()
            case .detail(let id): BasicDetailView(id: id)
            case .feed:           BasicFeedView()
            default:              EmptyView()
            }
        }
        .navigationTitle("Basic")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Views

private struct BasicHomeView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Section("Stack") {
                Button("Push Detail") { router.push(.detail(id: "42")) }
                Button("Push Detail (dedup)") { router.push(.detail(id: "42"), dedup: true) }
            }
            Section("Modal") {
                Button("Sheet Detail") { router.sheet(.detail(id: "sheet")) }
                Button("FullScreen Feed") { router.fullScreenCover(.feed) }
            }
        }
        .navigationTitle("Home")
    }
}

private struct BasicDetailView: View {
    let id: String
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Button("Push Nested Detail") { router.push(.detail(id: "child-\(id)")) }
            Button("Pop")               { router.pop() }
            Button("Pop to Root")       { router.popToRoot() }
        }
        .navigationTitle("Detail \(id)")
    }
}

private struct BasicFeedView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Button("Push Detail inside Cover") { router.push(.detail(id: "in-cover")) }
            Button("Dismiss")                  { router.dismiss() }
        }
        .navigationTitle("Feed (Cover)")
    }
}
