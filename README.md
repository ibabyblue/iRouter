# IRouter

A pure SwiftUI routing library for iOS 17+ and macOS 14+. Type-safe navigation for Push, Sheet, and FullScreenCover — with a built-in filter chain, dedup, and flush mode. Zero third-party dependencies.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## Features

- **Type-safe routes** — navigation targets are plain `Hashable & Sendable` enum cases; no stringly-typed paths
- **Three presentation modes** — Push (`NavigationStack`), Sheet, and FullScreenCover from a single unified API
- **Filter chain** — intercept any navigation before it executes; allow, block, or redirect to another route
- **Dedup & Flush** — skip duplicate push targets; clear all modals in one call for deep links and push notifications
- **Nested navigation** — each Sheet / FullScreenCover owns an independent child router with its own stack, inheriting the parent's filters
- **SwiftUI-native** — `@Observable`, `@MainActor`, zero UIKit, zero third-party dependencies

## Requirements

| | Minimum |
|---|---|
| iOS | 17.0 |
| macOS | 14.0 |
| Swift | 6.0 |
| Xcode | 16.3 |

> **Note:** FullScreenCover is not available on macOS. Push and Sheet work on both platforms.

## Installation

### Swift Package Manager

In Xcode choose **File → Add Package Dependencies**, enter the repository URL, or add to `Package.swift` directly:

```swift
dependencies: [
    .package(url: "https://github.com/ibabyblue/IRouter", from: "0.0.3")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "IRouter", package: "IRouter")
        ]
    )
]
```

## Quick Start

```swift
import IRouter

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

// 3. Place IRouterView at the root of your scene
IRouterView(router: router) { route in
    switch route {
    case .home:           HomeView()
    case .detail(let id): DetailView(id: id)
    case .settings:       SettingsView()
    case .login:          LoginView()
    }
}

// 4. Navigate from any child view via @Environment
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

### IRouterContext

```swift
@MainActor
public final class IRouterContext<Route: Hashable & Sendable>: Identifiable {
    public let id: UUID
    public let route: Route
    public let childRouter: IRouter<Route>
}
```

Created internally when a Sheet or FullScreenCover is presented. `childRouter` drives the modal's own independent navigation stack and inherits the parent's filter array.

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

Filters run in registration order before every navigation call. The first `.block` or `.redirect` terminates the chain. A redirected route re-enters the same filter chain from the top.

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
| `dedup` | `false` | Skip push if the route equals the current stack top |
| `flush` | `false` | Dismiss all modals before navigating — useful for deep links and push notifications |

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

### Block during loading

```swift
IRouterFilter { [weak self] _, _ in
    self?.isLoading == true ? .block : .allow
}
```

### Analytics logging

```swift
IRouterFilter { route, presentation in
    Analytics.track(route: route, via: presentation)
    return .allow
}
```

## Multi-Tab Setup

Each tab gets its own `IRouter` instance; they share no state by default:

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

## Edge-Case Behavior

| Scenario | Behavior |
|---|---|
| `pop()` on empty stack | No-op |
| `dismiss()` with cover + sheet | Dismisses cover first; sheet on next call; pops last stack item if no modals remain |
| `dedup: true` with matching stack top | Push is ignored |
| `flush: true` | Clears all modals before navigating |
| Filter `.redirect` | Terminates current chain; redirect target re-enters filters from the top |
| Sheet / cover navigation | Each gets its own `childRouter` that inherits parent filters |

## Design Notes

- `IRouter` is `@Observable` and `@MainActor`. Changes to `path`, `sheetContext`, and `coverContext` drive SwiftUI updates automatically.
- `IRouterView` binds a `NavigationStack` to `router.path`. Sheet and cover are driven by `.sheet(item:)` / `.fullScreenCover(item:)` bound to the context optionals — SwiftUI handles dismissal via binding, keeping state in sync without manual cleanup.
- Each sheet or cover creates an `IRouterContext` that owns a child `IRouter` with its own `path`. The child router inherits the parent's filter array, so guards and analytics apply uniformly across the whole hierarchy.
- The filter chain runs synchronously before every navigation call. Results are evaluated in order; the first non-`.allow` result short-circuits the rest. Redirected routes re-enter the chain from the top, preventing filter bypass.
- `dismissAndPush` clears all modals first, then calls `push`, which runs the filter chain normally.

## Demo

Open `demo/IRouterDemo.xcodeproj`, select a simulator and run. Covers four scenarios:

- **Basic** — push / pop / popToRoot, sheet, fullScreenCover, live state display
- **Filter** — allow / block / redirect / chain, with a live filter execution log
- **Flush** — deep link and push notification simulation using `flush: true`
- **Tab** — two independent routers in a `TabView`

## Out of Scope

- URL / deep link parsing (handle in `onOpenURL`, pass result to `push` / `sheet`)
- Alert / ConfirmationDialog (local UI state, not navigation destinations)
- Custom transition animations
- tvOS / watchOS
- Back-gesture interception

## License

IRouter is available under the MIT license. See the [LICENSE](LICENSE) file for details.
