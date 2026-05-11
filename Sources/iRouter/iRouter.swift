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

    public func sheet(_ route: Route, flush: Bool = false) {
        if flush { clearModals() }
        sheetContext = IRouterContext(route: route, filters: filters)
    }

    public func fullScreenCover(_ route: Route, flush: Bool = false) {
        if flush { clearModals() }
        coverContext = IRouterContext(route: route, filters: filters)
    }

    public func dismiss() {
        if coverContext != nil { coverContext = nil; return }
        if sheetContext != nil { sheetContext = nil; return }
        if !path.isEmpty       { path.removeLast() }
    }

    public func dismissAndPush(_ route: Route) {
        clearModals()
        push(route)
    }

    private func clearModals() {
        coverContext = nil
        sheetContext = nil
    }
}
