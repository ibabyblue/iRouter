import SwiftUI
import iRouter

// MARK: - ④ Child Router Demo
// Tests: sheet/cover 内部有独立导航栈；子 Router 继承父 Filter

struct ChildRouterDemoView: View {
    // 父 Filter：block .c
    @State private var router = IRouter<AppRoute>(
        root: .home,
        filters: [
            IRouterFilter { route, _ in
                if case .c = route { return .block }
                return .allow
            }
        ]
    )

    var body: some View {
        IRouterView(router: router) { _ in
            List {
                Section("父 Router State") {
                    RouterStateView(router: router)
                }
                Section("打开模态（内部子 Router 有独立导航栈）") {
                    Button("sheet(.login)  — Sheet 内可独立 push/pop") {
                        router.sheet(.login)
                    }
                    Button("fullScreenCover(.feed)  — Cover 内同理") {
                        router.fullScreenCover(.feed)
                    }
                }
                Section("验证子 Router 继承父 Filter") {
                    Text("打开 sheet/cover 后，在内部 push(.c) → 被 block\npush(.a) / push(.b) → 正常")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Child Router")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { DismissButton() }
            }
        }
        // 覆盖 IRouterView 默认的 sheet 展示，以便在内部显示子 Router 状态 + 操作按钮
        .sheet(item: Binding(get: { router.sheetContext },
                             set: { router.sheetContext = $0 })) { ctx in
            ChildInnerView(childRouter: ctx.childRouter, label: "Sheet")
        }
        .fullScreenCover(item: Binding(get: { router.coverContext },
                                      set: { router.coverContext = $0 })) { ctx in
            ChildInnerView(childRouter: ctx.childRouter, label: "Cover")
        }
    }
}

private struct ChildInnerView: View {
    let childRouter: IRouter<AppRoute>
    let label: String

    var body: some View {
        NavigationStack(path: Binding(get: { childRouter.path },
                                     set: { childRouter.path = $0 })) {
            List {
                Section("子 Router State（独立于父）") {
                    RouterStateView(router: childRouter)
                }
                Section("子 Router 操作") {
                    Button("push(.a)  → 正常") { childRouter.push(.a) }
                    Button("push(.b)  → 正常") { childRouter.push(.b) }
                    Button("push(.c)  → 继承父 Filter → 被 block") { childRouter.push(.c) }
                    Button("pop()") { childRouter.pop() }
                    Button("popToRoot()") { childRouter.popToRoot() }
                }
                Section("关闭 \(label)") {
                    Button("dismiss()") { childRouter.dismiss() }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("\(label) 子路由")
        }
        .environment(childRouter)
    }
}

// MARK: - ⑤ Multi-Router Demo
// Tests: 多个 IRouter 实例互相独立，各自维护 path / sheet / cover

struct MultiRouterDemoView: View {
    @State private var routerA = IRouter<AppRoute>(root: .home)
    @State private var routerB = IRouter<AppRoute>(root: .feed)

    var body: some View {
        NavigationStack {
            List {
                Section("Router A State") {
                    RouterStateView(router: routerA)
                }
                Section("Router A 操作（只影响 A）") {
                    Button("A: push(.a)") { routerA.push(.a) }
                    Button("A: push(.b)") { routerA.push(.b) }
                    Button("A: sheet(.login)") { routerA.sheet(.login) }
                    Button("A: pop()") { routerA.pop() }
                    Button("A: popToRoot()") { routerA.popToRoot() }
                    Button("A: dismiss()") { routerA.dismiss() }
                }

                Section("Router B State") {
                    RouterStateView(router: routerB)
                }
                Section("Router B 操作（只影响 B）") {
                    Button("B: push(.c)") { routerB.push(.c) }
                    Button("B: push(.settings)") { routerB.push(.settings) }
                    Button("B: sheet(.login)") { routerB.sheet(.login) }
                    Button("B: pop()") { routerB.pop() }
                    Button("B: popToRoot()") { routerB.popToRoot() }
                    Button("B: dismiss()") { routerB.dismiss() }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Multi-Router")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { DismissButton() }
            }
        }
        // Router A 的模态
        .sheet(item: Binding(get: { routerA.sheetContext },
                             set: { routerA.sheetContext = $0 })) { ctx in
            Text("Router A Sheet: \(ctx.route.description)").padding()
        }
        // Router B 的模态
        .sheet(item: Binding(get: { routerB.sheetContext },
                             set: { routerB.sheetContext = $0 })) { ctx in
            Text("Router B Sheet: \(ctx.route.description)").padding()
        }
    }
}
