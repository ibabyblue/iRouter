/// 路由拦截器
///
/// 在每次导航执行前触发，可放行、拦截或重定向到另一条路由。
///
/// ```swift
/// IRouterFilter { route, presentation in
///     if case .profile = route, !Auth.isLoggedIn {
///         return .redirect(.login, .sheet)
///     }
///     return .allow
/// }
/// ```
public struct IRouterFilter<Route: Hashable & Sendable>: Sendable {

    /// 拦截结果
    public enum Result: Sendable {
        /// 放行，继续执行导航
        case allow
        /// 拦截，不执行任何导航
        case block
        /// 重定向到另一条路由（redirect 本身同样过 Filter 链）
        case redirect(Route, IRouterPresentation)
    }

    let handler: @Sendable (Route, IRouterPresentation) -> Result

    /// 创建拦截器
    /// - Parameter handler: 拦截逻辑闭包，返回 `.allow` / `.block` / `.redirect`
    public init(_ handler: @Sendable @escaping (Route, IRouterPresentation) -> Result) {
        self.handler = handler
    }
}
