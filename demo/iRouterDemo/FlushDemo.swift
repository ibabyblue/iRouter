import SwiftUI
import iRouter

// MARK: - ② Modal Demo
// Tests: sheet / fullScreenCover / dismiss（cover > sheet > pop）
//        dismissAndPush / flush（push / sheet / cover 均支持）

struct ModalDemoView: View {
    @State private var router = IRouter<AppRoute>(root: .home)

    var body: some View {
        IRouterView(router: router) { route in
            ModalHomeView(route: route)
        }
    }
}

private struct ModalHomeView: View {
    let route: AppRoute
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Section("Router State") {
                RouterStateView(router: router)
            }
            Section("Sheet / FullScreenCover") {
                Button("sheet(.login)")           { router.sheet(.login) }
                Button("fullScreenCover(.feed)")  { router.fullScreenCover(.feed) }
            }
            Section("Stack（为 dismiss 优先级测试准备）") {
                Button("push(.a)") { router.push(.a) }
            }
            Section("Dismiss — 优先级 cover > sheet > pop") {
                Button("dismiss()  — 依次关闭 cover / sheet / pop") {
                    router.dismiss()
                }
                Button("dismissAndPush(.b)  — 清除所有模态 + push(.b)") {
                    router.dismissAndPush(.b)
                }
            }
            Section("Flush — 导航前先清除所有模态") {
                Button("先 sheet，再 push(.a, flush: true)") {
                    router.sheet(.login)
                    // 短暂延迟让 sheet 动画完成后再触发
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        router.push(.a, flush: true)
                    }
                }
                Button("先 cover，再 sheet(.settings, flush: true)") {
                    router.fullScreenCover(.feed)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        router.sheet(.settings, flush: true)
                    }
                }
                Button("先 cover，再 fullScreenCover(.login, flush: true)") {
                    router.fullScreenCover(.feed)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        router.fullScreenCover(.login, flush: true)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Modals — 当前: \(route.description)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { DismissButton() }
        }
    }
}
