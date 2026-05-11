import SwiftUI
import iRouter

// MARK: - ① Stack Demo
// Tests: push / pop / popToRoot / dedup

struct StackDemoView: View {
    @State private var router = IRouter<AppRoute>(root: .home)

    var body: some View {
        IRouterView(router: router) { route in
            StackHomeView(route: route)
        }
    }
}

private struct StackHomeView: View {
    let route: AppRoute
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Section("Router State") {
                RouterStateView(router: router)
            }
            Section("Push") {
                Button("push(.a)")  { router.push(.a) }
                Button("push(.b)")  { router.push(.b) }
                Button("push(.a) 再次 — 允许重复（no dedup）") { router.push(.a) }
            }
            Section("Dedup — 栈顶相同则忽略") {
                Button("push(.a, dedup: true) — 栈顶是 .a → 忽略") {
                    router.push(.a, dedup: true)
                }
                Button("push(.b, dedup: true) — 栈顶不是 .b → 正常入栈") {
                    router.push(.b, dedup: true)
                }
            }
            Section("Pop") {
                Button("pop()")       { router.pop() }
                Button("popToRoot()") { router.popToRoot() }
            }
            Section("关闭 Demo") {
                Button("退出", role: .destructive) { router.dismissAndPush(.home) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Stack — 当前: \(route.description)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                // 用 dismiss environment 关闭 fullScreenCover
                DismissButton()
            }
        }
    }
}

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button("关闭") { dismiss() }
    }
}
