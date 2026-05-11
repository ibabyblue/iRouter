import Foundation

/// Sheet / FullScreenCover 的呈现上下文
///
/// 由 `IRouter` 内部创建，持有触发呈现的路由和内部独立导航栈（子 Router）。
/// 子 Router 继承父 Router 的 Filter 链。
@MainActor
public final class IRouterContext<Route: Hashable & Sendable>: Identifiable {
    public let id = UUID()
    /// 触发呈现的路由（作为子 Router 的根页面）
    public let route: Route
    /// 子 Router，驱动 sheet/cover 内部的独立导航栈
    public let childRouter: IRouter<Route>

    init(route: Route, filters: [IRouterFilter<Route>]) {
        self.route = route
        self.childRouter = IRouter(root: route, filters: filters)
    }
}
