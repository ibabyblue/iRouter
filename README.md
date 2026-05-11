# iRouter

A pure SwiftUI routing package for iOS 17+. Type-safe navigation for Push, Sheet, and FullScreenCover, with a built-in filter chain, dedup, and flush mode. Zero third-party dependencies.

## Requirements

- iOS 17+
- Swift 6.0+
- Xcode 16+

## Installation

### Swift Package Manager

In Xcode choose **File → Add Package Dependencies**, enter the repository URL, or add it directly to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ibabyblue/iRouter", from: "0.0.1")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "iRouter", package: "iRouter")
        ]
    )
]
```

## Quick Start

```swift
import iRouter

// 1. Define routes
enum AppRoute: Hashable, Sendable {
    case home
    case detail(id: String)
    case settings
    case login
}

// 2. Create router (with optional filter)
@State var router = IRouter<AppRoute>(
    root: .home,
    filters: [
        IRouterFilter { route, _ in
            if case .settings = route, !Auth.isLoggedIn {
                return .redirect(.login, .sheet)
            }
            return .allow
        }
    ]
)

// 3. Place IRouterView at the root
IRouterView(router: router) { route in
    switch route {
    case .home:           HomeView()
    case .detail(let id): DetailView(id: id)
    case .settings:       SettingsView()
    case .login:          LoginView()
    }
}

// 4. Navigate from any child view
struct HomeView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        Button("Detail") { router.push(.detail(id: "42")) }
        Button("Settings") { router.push(.settings) }
    }
}
```

## API Reference

### IRouter

```swift
@MainActor @Observable
public final class IRouter<Route: Hashable & Sendable> {
    public let root: Route
    public var path: [Route]
    public var sheetContext: IRouterContext<Route>?
    public var coverContext: IRouterContext<Route>?

    public init(root: Route, filters: [IRouterFilter<Route>] = [])

    // Stack
    public func push(_ route: Route, dedup: Bool = false, flush: Bool = false)
    public func pop()
    public func popToRoot()

    // Modal
    public func sheet(_ route: Route, flush: Bool = false)
    public func fullScreenCover(_ route: Route, flush: Bool = false)
    public func dismiss()
    public func dismissAndPush(_ route: Route)
}
```

### IRouterView

```swift
public struct IRouterView<Route: Hashable & Sendable, Content: View>: View {
    public init(
        router: IRouter<Route>,
        @ViewBuilder destination: @escaping (Route) -> Content
    )
}
```

Wraps a `NavigationStack` and drives `.sheet` / `.fullScreenCover` from the router state. Injects the router into the environment so any child view can access it via `@Environment`.

### IRouterFilter

```swift
public struct IRouterFilter<Route: Hashable & Sendable>: Sendable {
    public enum Result: Sendable {
        case allow
        case block
        case redirect(Route, IRouterPresentation)
    }
    public init(_ handler: @Sendable @escaping (Route, IRouterPresentation) -> Result)
}
```

Filters run in registration order before every navigation. The first `.block` or `.redirect` terminates the chain. A redirected route goes through the same filter chain.

### IRouterPresentation

```swift
public enum IRouterPresentation: Sendable {
    case push
    case sheet
    case fullScreenCover
}
```

## Navigation Parameters

| Parameter | Default | Description |
|---|---|---|
| `dedup` | `false` | Skip push if route equals the current stack top |
| `flush` | `false` | Dismiss all modals before navigating — useful for deep links and push notifications |

## Multi-Tab Setup

Each tab gets its own `IRouter` instance. They share no state by default:

```swift
struct RootView: View {
    @State var tabARouter = IRouter<AppRoute>(root: .home)
    @State var tabBRouter = IRouter<AppRoute>(root: .feed)

    var body: some View {
        TabView {
            IRouterView(router: tabARouter) { ... }
                .tabItem { Label("Home", systemImage: "house") }
            IRouterView(router: tabBRouter) { ... }
                .tabItem { Label("Feed", systemImage: "list.bullet") }
        }
    }
}
```

## Filter Examples

### Login guard

```swift
IRouterFilter { route, _ in
    if case .profile = route, !Auth.isLoggedIn {
        return .redirect(.login, .sheet)
    }
    return .allow
}
```

### Analytics logging

```swift
IRouterFilter { route, presentation in
    Analytics.track(route: route, via: presentation)
    return .allow
}
```

## Edge-Case Behavior

| Scenario | Behavior |
|---|---|
| `pop()` on empty stack | No-op |
| `dismiss()` with cover + sheet | Dismisses cover first, then sheet on the next call, then pops the last stack item |
| `dedup: true` with matching stack top | Ignored |
| `flush: true` | Clears all modals before navigating |
| Filter `.redirect` | Terminates current chain; redirect target goes through the same filters |
| Sheet / cover navigation | Each gets its own child `IRouter` that inherits parent filters |

## Design Notes

- `IRouter` is `@Observable` and `@MainActor`. State changes (`path`, `sheetContext`, `coverContext`) drive SwiftUI updates automatically.
- `IRouterView` wraps a `NavigationStack` bound to `router.path`. Sheet and cover are presented via `.sheet(item:)` / `.fullScreenCover(item:)` bound to the context optionals — dismissal is handled by SwiftUI binding, keeping state in sync.
- Each sheet or cover creates an `IRouterContext` that owns a child `IRouter` with its own `path`. The child router inherits the parent's filter array, so guards and analytics apply uniformly across the whole hierarchy.
- The filter chain runs synchronously before every navigation call. Results are evaluated in order; the first non-`.allow` result short-circuits the remaining filters. Redirected routes re-enter the chain from the top, preventing filter bypass.
- `dismissAndPush` clears modals first, then calls `push`, which runs the filter chain normally.
- The public API is entirely SwiftUI; callers have no exposure to `NavigationStack` internals.

## Demo

Open `demo/iRouterDemo.xcodeproj`, select a simulator and run. Includes:

- **Basic** — push/pop, sheet, fullScreenCover
- **Filter** — login guard with redirect
- **Flush** — deep link / push notification simulation
- **Tab** — two independent routers in a TabView

## Out of Scope

- URL / deep link parsing (handle in `onOpenURL`, pass result to `push` / `sheet`)
- Alert / ConfirmationDialog (local UI state, not navigation destinations)
- Custom transition animations
- macOS / tvOS / watchOS
- Back-gesture interception
