import Foundation
import Observation

@MainActor
@Observable
public final class IRouter<Route: Hashable & Sendable> {
    public let root: Route
    public var path: [Route] = []
    public var sheetContext: IRouterContext<Route>? = nil
    public var coverContext: IRouterContext<Route>? = nil
    private let filters: [IRouterFilter<Route>]

    public init(root: Route, filters: [IRouterFilter<Route>] = []) {
        self.root = root
        self.filters = filters
    }

    public func push(_ route: Route, dedup: Bool = false, flush: Bool = false) {
        if flush { clearModals() }
        if dedup && path.last == route { return }
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func popToRoot() {
        path.removeAll()
    }

    public func sheet(_ route: Route, flush: Bool = false) {}
    public func fullScreenCover(_ route: Route, flush: Bool = false) {}
    public func dismiss() {}
    public func dismissAndPush(_ route: Route) {}

    private func clearModals() {
        coverContext = nil
        sheetContext = nil
    }
}
