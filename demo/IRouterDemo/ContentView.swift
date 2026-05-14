import SwiftUI
import IRouter

// MARK: - Route

enum AppRoute: Hashable, Sendable {
    case home, a, b, c, settings, login, feed
}

extension AppRoute: CustomStringConvertible {
    var description: String {
        switch self {
        case .home:     return "home"
        case .a:        return "A"
        case .b:        return "B"
        case .c:        return "C"
        case .settings: return "settings"
        case .login:    return "login"
        case .feed:     return "feed"
        }
    }
}

// MARK: - Auth (demo-only)

@MainActor
final class AuthState {
    static let shared = AuthState()
    var isLoggedIn = false
    private init() {}
}

// MARK: - Router state widget

struct RouterStateView: View {
    let router: IRouter<AppRoute>
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            stateRow(icon: "square.stack",
                     text: "path: [\(router.path.map(\.description).joined(separator: ", "))]")
            stateRow(icon: "rectangle.bottomthird.inset.filled",
                     text: "sheet: \(router.sheetContext.map(\.route.description) ?? "nil")")
            stateRow(icon: "rectangle.inset.filled",
                     text: "cover: \(router.coverContext.map(\.route.description) ?? "nil")")
        }
        .font(.caption.monospaced())
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func stateRow(icon: String, text: String) -> some View {
        Label(text, systemImage: icon).foregroundStyle(.secondary)
    }
}

// MARK: - Demo picker
// Each demo is presented as a fullScreenCover to avoid nested NavigationStack.

private enum Demo: Int, Identifiable {
    case stack, modals, filter, childRouter, multiRouter
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .stack:       return "① Stack — push / pop / popToRoot / dedup"
        case .modals:      return "② Modals — sheet / cover / dismiss / flush"
        case .filter:      return "③ Filter — allow / block / redirect / chain"
        case .childRouter: return "④ Child Router — 独立子栈 + Filter 继承"
        case .multiRouter: return "⑤ Multi-Router — 两实例互相独立"
        }
    }
}

struct ContentView: View {
    @State private var activeDemo: Demo?

    var body: some View {
        NavigationStack {
            List(Demo.allCases, id: \.id) { demo in
                Button(demo.title) { activeDemo = demo }
            }
            .navigationTitle("IRouter 功能测试")
        }
        .fullScreenCover(item: $activeDemo) { demo in
            switch demo {
            case .stack:       StackDemoView()
            case .modals:      ModalDemoView()
            case .filter:      FilterDemoView()
            case .childRouter: ChildRouterDemoView()
            case .multiRouter: MultiRouterDemoView()
            }
        }
    }
}

extension Demo: CaseIterable {}
