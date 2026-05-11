import SwiftUI
import iRouter

// MARK: - ③ Filter Demo
// Tests: allow / block / redirect / chain 顺序（首个 block 终止）
//        redirect 目标再过 filter 链

struct FilterDemoView: View {
    // 每个子场景用独立 router，通过 push 导航到不同 filter 测试页
    @State private var router = IRouter<AppRoute>(root: .home)

    var body: some View {
        IRouterView(router: router) { route in
            switch route {
            case .home:     FilterMenuView()
            case .a:        AllowFilterTestView()
            case .b:        BlockFilterTestView()
            case .c:        RedirectFilterTestView()
            case .settings: ChainFilterTestView()
            default:        EmptyView()
            }
        }
    }
}

// MARK: 菜单

private struct FilterMenuView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Button("Allow — push(.a) → 进入 Allow 测试")      { router.push(.a) }
            Button("Block — push(.b) → 进入 Block 测试")      { router.push(.b) }
            Button("Redirect — push(.c) → 进入 Redirect 测试") { router.push(.c) }
            Button("Chain — push(.settings) → 进入 Chain 测试") { router.push(.settings) }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Filter 测试")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { DismissButton() }
        }
    }
}

// MARK: Allow

private struct AllowFilterTestView: View {
    // router 只有 allow filter：所有导航正常
    @State private var router = IRouter<AppRoute>(
        root: .home,
        filters: [IRouterFilter { _, _ in .allow }]
    )
    var body: some View {
        IRouterView(router: router) { _ in
            List {
                Section("State（预期：操作正常执行）") {
                    RouterStateView(router: router)
                }
                Section {
                    Button("push(.a)  → path + 1") { router.push(.a) }
                    Button("sheet(.login)  → sheetContext 设置") { router.sheet(.login) }
                    Button("dismiss()") { router.dismiss() }
                    Button("popToRoot()") { router.popToRoot() }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Allow Filter")
        }
    }
}

// MARK: Block

private struct BlockFilterTestView: View {
    // router 只有 block filter：所有导航被拦截
    @State private var router = IRouter<AppRoute>(
        root: .home,
        filters: [IRouterFilter { _, _ in .block }]
    )
    var body: some View {
        IRouterView(router: router) { _ in
            List {
                Section("State（预期：state 始终不变）") {
                    RouterStateView(router: router)
                }
                Section {
                    Button("push(.a)  → 被拦截，path 仍为 []") { router.push(.a) }
                    Button("sheet(.login)  → 被拦截，sheet 仍为 nil") { router.sheet(.login) }
                    Button("fullScreenCover(.feed)  → 被拦截") { router.fullScreenCover(.feed) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Block Filter")
        }
    }
}

// MARK: Redirect

private struct RedirectFilterTestView: View {
    // push(.settings) → redirect 到 sheet(.login)；redirect 目标 .login 再过 filter 链（allow）
    @State private var router = IRouter<AppRoute>(
        root: .home,
        filters: [
            IRouterFilter { route, _ in
                if case .settings = route { return .redirect(.login, .sheet) }
                return .allow
            }
        ]
    )
    var body: some View {
        IRouterView(router: router) { _ in
            List {
                Section("State") {
                    RouterStateView(router: router)
                }
                Section("预期") {
                    Button("push(.a)  → 正常，path = [a]") { router.push(.a) }
                    Button("push(.settings)  → redirect → sheet(.login)") {
                        router.push(.settings)
                    }
                    Button("dismiss()  → 关闭 sheet") { router.dismiss() }
                    Button("popToRoot()") { router.popToRoot() }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Redirect Filter")
        }
    }
}

// MARK: Chain

private struct ChainFilterTestView: View {
    @State private var log: [String] = []
    @State private var router = IRouter<AppRoute>(root: .home)

    var body: some View {
        IRouterView(router: router) { _ in
            List {
                Section("State") {
                    RouterStateView(router: router)
                }
                Section("Filter 执行日志") {
                    if log.isEmpty {
                        Text("（尚未操作）").foregroundStyle(.secondary)
                    }
                    ForEach(Array(log.enumerated()), id: \.offset) { _, entry in
                        Text(entry).font(.caption.monospaced())
                    }
                    if !log.isEmpty {
                        Button("清空日志") { resetRouter() }
                    }
                }
                Section("预期") {
                    Button("push(.a)  → f1✓ f2✓，正常入栈") {
                        resetRouter()
                        router.push(.a)
                    }
                    Button("push(.b)  → f1 block，f2 不执行") {
                        resetRouter()
                        router.push(.b)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Filter Chain")
        }
        .onAppear { resetRouter() }
    }

    private func resetRouter() {
        log = []
        router = IRouter<AppRoute>(
            root: .home,
            filters: [
                IRouterFilter { [self] route, _ in
                    Task { @MainActor in log.append("filter1 called") }
                    if case .b = route {
                        Task { @MainActor in log.append("filter1 → .block (chain stops)") }
                        return .block
                    }
                    Task { @MainActor in log.append("filter1 → .allow") }
                    return .allow
                },
                IRouterFilter { [self] _, _ in
                    Task { @MainActor in log.append("filter2 called → .allow") }
                    return .allow
                },
            ]
        )
    }
}
