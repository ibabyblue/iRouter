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
        switch runFilters(route: route, presentation: .push) {
        case .allow:
            if dedup && path.last == route { return }
            path.append(route)
        case .block:
            break
        case .redirect(let newRoute, let newPresentation):
            navigate(to: newRoute, as: newPresentation)
        }
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
        switch runFilters(route: route, presentation: .sheet) {
        case .allow:
            sheetContext = IRouterContext(route: route, filters: filters)
        case .block:
            break
        case .redirect(let newRoute, let newPresentation):
            navigate(to: newRoute, as: newPresentation)
        }
    }

    public func fullScreenCover(_ route: Route, flush: Bool = false) {
        if flush { clearModals() }
        switch runFilters(route: route, presentation: .fullScreenCover) {
        case .allow:
            coverContext = IRouterContext(route: route, filters: filters)
        case .block:
            break
        case .redirect(let newRoute, let newPresentation):
            navigate(to: newRoute, as: newPresentation)
        }
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

    private func runFilters(
        route: Route,
        presentation: IRouterPresentation
    ) -> IRouterFilter<Route>.Result {
        for filter in filters {
            let result = filter.handler(route, presentation)
            switch result {
            case .allow:            continue
            case .block, .redirect: return result
            }
        }
        return .allow
    }

    private func navigate(to route: Route, as presentation: IRouterPresentation) {
        switch presentation {
        case .push:            push(route)
        case .sheet:           sheet(route)
        case .fullScreenCover: fullScreenCover(route)
        }
    }
}
