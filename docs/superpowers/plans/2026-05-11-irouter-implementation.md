# iRouter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build iRouter — 一个纯 SwiftUI、类型安全的路由 SPM 包，支持 Push/Pop、Sheet、FullScreenCover，内置 Filter 拦截链、dedup 去重和 flush 模式。

**Architecture:** `IRouter<Route>` 是 `@Observable @MainActor` 类，持有 `path`、`sheetContext`、`coverContext` 三段状态。`IRouterView<Route, Content>` 用 `NavigationStack` + `.sheet` + `.fullScreenCover` 驱动渲染，通过 `@Environment` 向子 View 注入 Router。Filter 链在每次导航前按序执行，支持放行 / 拦截 / 重定向。

**Tech Stack:** Swift 6.0 strict concurrency，SwiftUI，NavigationStack (iOS 17+)，Swift Testing，SPM swift-tools-version 6.2，零第三方依赖

---

## 文件结构

```
iRouter/
├── Package.swift
├── .gitignore
├── README.md
├── Sources/iRouter/
│   ├── IRouterPresentation.swift   — push/sheet/fullScreenCover 枚举
│   ├── IRouterFilter.swift         — 拦截器结构体 + Result 枚举
│   ├── IRouterContext.swift        — sheet/cover 呈现上下文，持有子 Router
│   ├── IRouter.swift               — 核心状态持有者，所有导航操作入口
│   └── IRouterView.swift           — SwiftUI 容器，驱动 NavigationStack + 模态
├── Tests/iRouterTests/
│   └── IRouterTests.swift          — 单元测试（Swift Testing）
└── demo/
    └── iRouterDemo/                — Xcode iOS App（手动在 Xcode 创建）
        ├── iRouterDemoApp.swift
        ├── ContentView.swift
        ├── BasicDemo.swift
        ├── FilterDemo.swift
        ├── FlushDemo.swift
        └── TabDemo.swift
```

---

## Task 1：Package 脚手架

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`

- [ ] **Step 1: 创建 Package.swift**

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "iRouter",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "iRouter", targets: ["iRouter"]),
    ],
    targets: [
        .target(name: "iRouter"),
        .testTarget(name: "iRouterTests", dependencies: ["iRouter"]),
    ]
)
```

- [ ] **Step 2: 创建目录结构**

```bash
mkdir -p Sources/iRouter Tests/iRouterTests
```

- [ ] **Step 3: 创建 .gitignore**

```
# macOS
.DS_Store

# Xcode
*.xcuserstate
xcuserdata/
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
DerivedData/

# Swift Package Manager
.build/
.swiftpm/

# Superpowers / Claude
.superpowers/
.claude/
docs/
```

- [ ] **Step 4: 验证包结构可编译**

```bash
swift build
```

Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Package.swift .gitignore Sources Tests
git commit -m "chore: init iRouter SPM package scaffold"
```

---

## Task 2：IRouterPresentation + IRouterFilter + IRouterContext

**Files:**
- Create: `Sources/iRouter/IRouterPresentation.swift`
- Create: `Sources/iRouter/IRouterFilter.swift`
- Create: `Sources/iRouter/IRouterContext.swift`

这三个类型结构简单，直接实现，无需 TDD 循环（行为在 IRouter 测试中间接覆盖）。

- [ ] **Step 1: 创建 IRouterPresentation.swift**

```swift
/// 路由呈现方式
public enum IRouterPresentation: Sendable {
    case push
    case sheet
    case fullScreenCover
}
```

- [ ] **Step 2: 创建 IRouterFilter.swift**

```swift
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
```

- [ ] **Step 3: 创建 IRouterContext.swift**

```swift
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
```

- [ ] **Step 4: 验证编译**

```bash
swift build
```

Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/iRouter/IRouterPresentation.swift \
        Sources/iRouter/IRouterFilter.swift \
        Sources/iRouter/IRouterContext.swift
git commit -m "feat: add IRouterPresentation, IRouterFilter, IRouterContext"
```

---

## Task 3：IRouter — Push/Pop 操作（TDD）

**Files:**
- Create: `Sources/iRouter/IRouter.swift`
- Create: `Tests/iRouterTests/IRouterTests.swift`

- [ ] **Step 1: 创建空壳 IRouter.swift（让测试可以编译）**

```swift
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

    public func push(_ route: Route, dedup: Bool = false, flush: Bool = false) {}
    public func pop() {}
    public func popToRoot() {}
    public func sheet(_ route: Route, flush: Bool = false) {}
    public func fullScreenCover(_ route: Route, flush: Bool = false) {}
    public func dismiss() {}
    public func dismissAndPush(_ route: Route) {}
}
```

- [ ] **Step 2: 写 Push/Pop 失败测试**

```swift
// Tests/iRouterTests/IRouterTests.swift
import Testing
@testable import iRouter

private enum TR: Hashable, Sendable {
    case home, detail, settings, login, feed
}

@Suite struct IRouterTests {

    // MARK: - push

    @Test @MainActor
    func pushAppendsRoute() {
        let r = IRouter<TR>(root: .home)
        r.push(.detail)
        #expect(r.path == [.detail])
    }

    @Test @MainActor
    func pushMultiple() {
        let r = IRouter<TR>(root: .home)
        r.push(.detail)
        r.push(.settings)
        #expect(r.path == [.detail, .settings])
    }

    // MARK: - pop

    @Test @MainActor
    func popRemovesLast() {
        let r = IRouter<TR>(root: .home)
        r.push(.detail)
        r.push(.settings)
        r.pop()
        #expect(r.path == [.detail])
    }

    @Test @MainActor
    func popOnEmptyDoesNothing() {
        let r = IRouter<TR>(root: .home)
        r.pop()
        #expect(r.path.isEmpty)
    }

    // MARK: - popToRoot

    @Test @MainActor
    func popToRootClearsPath() {
        let r = IRouter<TR>(root: .home)
        r.push(.detail)
        r.push(.settings)
        r.popToRoot()
        #expect(r.path.isEmpty)
    }

    // MARK: - dedup

    @Test @MainActor
    func dedupBlocksTopDuplicate() {
        let r = IRouter<TR>(root: .home)
        r.push(.detail)
        r.push(.detail, dedup: true)
        #expect(r.path == [.detail])
    }

    @Test @MainActor
    func dedupAllowsIfNotAtTop() {
        let r = IRouter<TR>(root: .home)
        r.push(.detail)
        r.push(.settings)
        r.push(.detail, dedup: true)
        #expect(r.path == [.detail, .settings, .detail])
    }

    @Test @MainActor
    func noDedupAllowsDuplicate() {
        let r = IRouter<TR>(root: .home)
        r.push(.detail)
        r.push(.detail)
        #expect(r.path == [.detail, .detail])
    }
}
```

- [ ] **Step 3: 运行测试，确认失败**

```bash
swift test --filter IRouterTests
```

Expected（部分失败输出）：
```
✗ Test pushAppendsRoute() failed: Expectation failed: (r.path → []) == [.detail]
```

- [ ] **Step 4: 实现 push / pop / popToRoot**

将 `IRouter.swift` 中对应方法替换为：

```swift
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
```

同时在类内部添加私有辅助方法：

```swift
private func clearModals() {
    coverContext = nil
    sheetContext = nil
}
```

- [ ] **Step 5: 运行测试，确认通过**

```bash
swift test --filter IRouterTests
```

Expected:
```
◇ Test run with 8 tests passed after 0.0XX seconds.
```

- [ ] **Step 6: Commit**

```bash
git add Sources/iRouter/IRouter.swift Tests/iRouterTests/IRouterTests.swift
git commit -m "feat: implement IRouter push/pop/popToRoot with TDD"
```

---

## Task 4：IRouter — 模态操作（TDD）

**Files:**
- Modify: `Sources/iRouter/IRouter.swift`
- Modify: `Tests/iRouterTests/IRouterTests.swift`

- [ ] **Step 1: 追加模态失败测试**

在 `IRouterTests.swift` 的 `IRouterTests` suite 末尾追加：

```swift
    // MARK: - flush

    @Test @MainActor
    func flushClearsSheetBeforePush() {
        let r = IRouter<TR>(root: .home)
        r.sheetContext = IRouterContext(route: .login, filters: [])
        r.push(.detail, flush: true)
        #expect(r.sheetContext == nil)
        #expect(r.path == [.detail])
    }

    @Test @MainActor
    func flushClearsCoverBeforePush() {
        let r = IRouter<TR>(root: .home)
        r.coverContext = IRouterContext(route: .settings, filters: [])
        r.push(.detail, flush: true)
        #expect(r.coverContext == nil)
        #expect(r.path == [.detail])
    }

    // MARK: - sheet

    @Test @MainActor
    func sheetSetsContext() {
        let r = IRouter<TR>(root: .home)
        r.sheet(.login)
        #expect(r.sheetContext?.route == .login)
    }

    @Test @MainActor
    func sheetCreatesChildRouterWithSameRoot() {
        let r = IRouter<TR>(root: .home)
        r.sheet(.login)
        #expect(r.sheetContext?.childRouter.root == .login)
    }

    // MARK: - fullScreenCover

    @Test @MainActor
    func coverSetsContext() {
        let r = IRouter<TR>(root: .home)
        r.fullScreenCover(.settings)
        #expect(r.coverContext?.route == .settings)
    }

    // MARK: - dismiss

    @Test @MainActor
    func dismissCoverFirst() {
        let r = IRouter<TR>(root: .home)
        r.sheetContext = IRouterContext(route: .login, filters: [])
        r.coverContext = IRouterContext(route: .settings, filters: [])
        r.dismiss()
        #expect(r.coverContext == nil)
        #expect(r.sheetContext?.route == .login)
    }

    @Test @MainActor
    func dismissSheetIfNoCover() {
        let r = IRouter<TR>(root: .home)
        r.sheetContext = IRouterContext(route: .login, filters: [])
        r.dismiss()
        #expect(r.sheetContext == nil)
    }

    @Test @MainActor
    func dismissPopsPathIfNoModals() {
        let r = IRouter<TR>(root: .home)
        r.push(.detail)
        r.dismiss()
        #expect(r.path.isEmpty)
    }

    @Test @MainActor
    func dismissDoesNothingWhenEmpty() {
        let r = IRouter<TR>(root: .home)
        r.dismiss()
        #expect(r.path.isEmpty)
        #expect(r.sheetContext == nil)
        #expect(r.coverContext == nil)
    }

    // MARK: - dismissAndPush

    @Test @MainActor
    func dismissAndPushClearsModalsAndPushes() {
        let r = IRouter<TR>(root: .home)
        r.sheetContext = IRouterContext(route: .login, filters: [])
        r.coverContext = IRouterContext(route: .settings, filters: [])
        r.dismissAndPush(.detail)
        #expect(r.sheetContext == nil)
        #expect(r.coverContext == nil)
        #expect(r.path == [.detail])
    }
```

- [ ] **Step 2: 运行测试，确认新增测试失败**

```bash
swift test --filter IRouterTests
```

Expected（有部分失败）：
```
✗ Test sheetSetsContext() failed: Expectation failed: (r.sheetContext?.route → nil) == .login
```

- [ ] **Step 3: 实现 sheet / fullScreenCover / dismiss / dismissAndPush**

将 `IRouter.swift` 中对应空方法替换：

```swift
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
```

- [ ] **Step 4: 运行测试，确认全部通过**

```bash
swift test --filter IRouterTests
```

Expected:
```
◇ Test run with 20 tests passed after 0.0XX seconds.
```

- [ ] **Step 5: Commit**

```bash
git add Sources/iRouter/IRouter.swift Tests/iRouterTests/IRouterTests.swift
git commit -m "feat: implement IRouter sheet/cover/dismiss/dismissAndPush with TDD"
```

---

## Task 5：IRouter — Filter 链（TDD）

**Files:**
- Modify: `Sources/iRouter/IRouter.swift`
- Modify: `Tests/iRouterTests/IRouterTests.swift`

- [ ] **Step 1: 追加 Filter 失败测试**

在 `IRouterTests.swift` suite 末尾追加：

```swift
    // MARK: - filter: allow

    @Test @MainActor
    func filterAllowLetsPushThrough() {
        let r = IRouter<TR>(root: .home, filters: [
            IRouterFilter { _, _ in .allow }
        ])
        r.push(.detail)
        #expect(r.path == [.detail])
    }

    // MARK: - filter: block

    @Test @MainActor
    func filterBlockPreventsPush() {
        let r = IRouter<TR>(root: .home, filters: [
            IRouterFilter { _, _ in .block }
        ])
        r.push(.detail)
        #expect(r.path.isEmpty)
    }

    @Test @MainActor
    func filterBlockPreventsSheet() {
        let r = IRouter<TR>(root: .home, filters: [
            IRouterFilter { _, _ in .block }
        ])
        r.sheet(.login)
        #expect(r.sheetContext == nil)
    }

    @Test @MainActor
    func filterBlockPreventsCover() {
        let r = IRouter<TR>(root: .home, filters: [
            IRouterFilter { _, _ in .block }
        ])
        r.fullScreenCover(.settings)
        #expect(r.coverContext == nil)
    }

    // MARK: - filter: redirect

    @Test @MainActor
    func filterRedirectsToLoginSheet() {
        let r = IRouter<TR>(root: .home, filters: [
            IRouterFilter { route, _ in
                if case .settings = route { return .redirect(.login, .sheet) }
                return .allow
            }
        ])
        r.push(.settings)
        #expect(r.path.isEmpty)
        #expect(r.sheetContext?.route == .login)
    }

    // MARK: - filter chain order

    @Test @MainActor
    func filterChainStopsAtFirstBlock() {
        var order: [Int] = []
        let r = IRouter<TR>(root: .home, filters: [
            IRouterFilter { _, _ in order.append(1); return .block },
            IRouterFilter { _, _ in order.append(2); return .allow },
        ])
        r.push(.detail)
        #expect(order == [1])
    }

    @Test @MainActor
    func filterChainAllFiltersRunOnAllAllow() {
        var order: [Int] = []
        let r = IRouter<TR>(root: .home, filters: [
            IRouterFilter { _, _ in order.append(1); return .allow },
            IRouterFilter { _, _ in order.append(2); return .allow },
        ])
        r.push(.detail)
        #expect(order == [1, 2])
        #expect(r.path == [.detail])
    }

    // MARK: - child router inherits filters

    @Test @MainActor
    func childRouterInheritsFilters() {
        let r = IRouter<TR>(root: .home, filters: [
            IRouterFilter { route, _ in
                if case .detail = route { return .block }
                return .allow
            }
        ])
        r.sheet(.login)
        let child = r.sheetContext!.childRouter
        child.push(.detail)
        #expect(child.path.isEmpty)
    }
```

- [ ] **Step 2: 运行测试，确认新增测试失败**

```bash
swift test --filter IRouterTests
```

Expected（filter 相关测试失败）：
```
✗ Test filterBlockPreventsPush() failed: Expectation failed: (r.path → [.detail]) == []
```

- [ ] **Step 3: 在 IRouter.swift 添加 Filter 链执行逻辑**

在 `IRouter.swift` 的 `clearModals()` 下方添加两个私有方法：

```swift
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
```

- [ ] **Step 4: 将 Filter 链接入 push / sheet / fullScreenCover**

将三个方法改为：

```swift
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
```

- [ ] **Step 5: 运行全部测试，确认全部通过**

```bash
swift test
```

Expected:
```
◇ Test run with 29 tests passed after 0.0XX seconds.
```

- [ ] **Step 6: Commit**

```bash
git add Sources/iRouter/IRouter.swift Tests/iRouterTests/IRouterTests.swift
git commit -m "feat: integrate filter chain into IRouter navigation methods"
```

---

## Task 6：IRouterView

**Files:**
- Create: `Sources/iRouter/IRouterView.swift`

IRouterView 是纯渲染层，行为由 IRouter 测试覆盖，此处只需验证编译通过。

- [ ] **Step 1: 创建 IRouterView.swift**

```swift
import SwiftUI

/// iRouter 的 SwiftUI 容器视图
///
/// 将 `IRouter` 的状态驱动到 `NavigationStack`、`.sheet`、`.fullScreenCover`，
/// 并通过 `@Environment` 向整个子视图树注入 Router。
///
/// ```swift
/// IRouterView(router: router) { route in
///     switch route {
///     case .home:           HomeView()
///     case .detail(let id): DetailView(id: id)
///     }
/// }
/// ```
public struct IRouterView<Route: Hashable & Sendable, Content: View>: View {

    @Bindable private var router: IRouter<Route>
    private let destination: (Route) -> Content

    /// - Parameters:
    ///   - router: 驱动此视图的 IRouter 实例
    ///   - destination: 将 Route 映射为对应 View 的 ViewBuilder 闭包
    public init(
        router: IRouter<Route>,
        @ViewBuilder destination: @escaping (Route) -> Content
    ) {
        _router = Bindable(router)
        self.destination = destination
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            destination(router.root)
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
        .sheet(item: $router.sheetContext) { ctx in
            IRouterView(router: ctx.childRouter, destination: destination)
        }
        .fullScreenCover(item: $router.coverContext) { ctx in
            IRouterView(router: ctx.childRouter, destination: destination)
        }
        .environment(router)
    }
}
```

- [ ] **Step 2: 验证编译**

```bash
swift build
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/iRouter/IRouterView.swift
git commit -m "feat: implement IRouterView SwiftUI container"
```

---

## Task 7：Demo App

**Files:**
- Create: `demo/iRouterDemo/iRouterDemoApp.swift`
- Create: `demo/iRouterDemo/ContentView.swift`
- Create: `demo/iRouterDemo/BasicDemo.swift`
- Create: `demo/iRouterDemo/FilterDemo.swift`
- Create: `demo/iRouterDemo/FlushDemo.swift`
- Create: `demo/iRouterDemo/TabDemo.swift`

- [ ] **Step 1: 在 Xcode 创建 Demo 工程**

1. Xcode → File → New → App
2. Product Name: `iRouterDemo`，Interface: SwiftUI，Language: Swift
3. 存储到 `demo/` 目录下（保存后路径为 `demo/iRouterDemo.xcodeproj`）
4. File → Add Package Dependencies → Add Local → 选择 `../..`（iRouter 包根目录）
5. 在 target 的 Frameworks 中添加 `iRouter`

- [ ] **Step 2: 创建 iRouterDemoApp.swift**

```swift
import SwiftUI

@main
struct iRouterDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 3: 创建 ContentView.swift**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Basic Navigation") { BasicDemoView() }
                NavigationLink("Filter / Auth Guard") { FilterDemoView() }
                NavigationLink("Flush Mode") { FlushDemoView() }
                NavigationLink("Multi-Tab Routers") { TabDemoView() }
            }
            .navigationTitle("iRouter Demo")
        }
    }
}
```

- [ ] **Step 4: 创建 BasicDemo.swift**

演示 push、pop、popToRoot、sheet、fullScreenCover、dismiss、dismissAndPush。

```swift
import SwiftUI
import iRouter

enum BasicRoute: Hashable, Sendable {
    case home
    case detail(index: Int)
    case settings
    case profile
}

struct BasicDemoView: View {
    @State private var router = IRouter<BasicRoute>(root: .home)

    var body: some View {
        IRouterView(router: router) { route in
            switch route {
            case .home:              BasicHomeView()
            case .detail(let idx):   BasicDetailView(index: idx)
            case .settings:          BasicSettingsView()
            case .profile:           BasicProfileView()
            }
        }
        .navigationTitle("Basic")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BasicHomeView: View {
    @Environment(IRouter<BasicRoute>.self) var router
    @State private var counter = 0

    var body: some View {
        List {
            Section("Push") {
                Button("Push Detail") { router.push(.detail(index: counter)); counter += 1 }
                Button("Push Detail (dedup)") { router.push(.detail(index: 0), dedup: true) }
                Button("Pop to Root") { router.popToRoot() }
            }
            Section("Modal") {
                Button("Sheet: Settings") { router.sheet(.settings) }
                Button("FullScreenCover: Profile") { router.fullScreenCover(.profile) }
            }
        }
        .navigationTitle("Home")
    }
}

struct BasicDetailView: View {
    @Environment(IRouter<BasicRoute>.self) var router
    let index: Int

    var body: some View {
        VStack(spacing: 16) {
            Text("Detail #\(index)").font(.title)
            Button("Push Another Detail") { router.push(.detail(index: index + 1)) }
            Button("Pop") { router.pop() }
            Button("Pop to Root") { router.popToRoot() }
            Button("Sheet from Detail") { router.sheet(.settings) }
            Button("Dismiss & Push Profile (dismissAndPush)") {
                router.dismissAndPush(.profile)
            }
        }
        .navigationTitle("Detail \(index)")
    }
}

struct BasicSettingsView: View {
    @Environment(IRouter<BasicRoute>.self) var router

    var body: some View {
        VStack(spacing: 16) {
            Text("Settings Sheet").font(.title2)
            Button("Push Inside Sheet") { router.push(.detail(index: 99)) }
            Button("Dismiss") { router.dismiss() }
        }
        .navigationTitle("Settings")
    }
}

struct BasicProfileView: View {
    @Environment(IRouter<BasicRoute>.self) var router

    var body: some View {
        VStack(spacing: 16) {
            Text("Profile (FullScreenCover)").font(.title2)
            Button("Dismiss") { router.dismiss() }
        }
    }
}
```

- [ ] **Step 5: 创建 FilterDemo.swift**

演示 Filter 拦截：未登录时访问 `.profile` 被重定向到 `.login` Sheet。

```swift
import SwiftUI
import iRouter

enum FilterRoute: Hashable, Sendable {
    case home
    case profile
    case login
}

@Observable
final class AuthState: @unchecked Sendable {
    var isLoggedIn = false
}

struct FilterDemoView: View {
    @State private var auth = AuthState()

    var body: some View {
        let router = IRouter<FilterRoute>(
            root: .home,
            filters: [
                IRouterFilter { [auth] route, _ in
                    if case .profile = route, !auth.isLoggedIn {
                        return .redirect(.login, .sheet)
                    }
                    return .allow
                }
            ]
        )
        IRouterView(router: router) { route in
            switch route {
            case .home:    FilterHomeView(auth: auth)
            case .profile: FilterProfileView()
            case .login:   FilterLoginView(auth: auth)
            }
        }
        .navigationTitle("Filter Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FilterHomeView: View {
    @Environment(IRouter<FilterRoute>.self) var router
    let auth: AuthState

    var body: some View {
        VStack(spacing: 16) {
            Text(auth.isLoggedIn ? "已登录 ✅" : "未登录 ❌").font(.headline)
            Button("进入 Profile（未登录会被拦截）") {
                router.push(.profile)
            }
            if auth.isLoggedIn {
                Button("退出登录") { auth.isLoggedIn = false }
            }
        }
        .navigationTitle("Home")
    }
}

struct FilterProfileView: View {
    var body: some View {
        Text("Profile 页面（需登录才能进入）")
            .navigationTitle("Profile")
    }
}

struct FilterLoginView: View {
    @Environment(IRouter<FilterRoute>.self) var router
    let auth: AuthState

    var body: some View {
        VStack(spacing: 16) {
            Text("请登录").font(.title2)
            Button("模拟登录") {
                auth.isLoggedIn = true
                router.dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Login")
    }
}
```

- [ ] **Step 6: 创建 FlushDemo.swift**

演示 flush 模式：Sheet 展示时模拟通知到来，flush push 自动关闭模态再跳转。

```swift
import SwiftUI
import iRouter

enum FlushRoute: Hashable, Sendable {
    case home
    case modal
    case notification(title: String)
}

struct FlushDemoView: View {
    @State private var router = IRouter<FlushRoute>(root: .home)

    var body: some View {
        IRouterView(router: router) { route in
            switch route {
            case .home:                    FlushHomeView()
            case .modal:                   FlushModalView()
            case .notification(let title): FlushNotificationView(title: title)
            }
        }
        .navigationTitle("Flush Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FlushHomeView: View {
    @Environment(IRouter<FlushRoute>.self) var router

    var body: some View {
        VStack(spacing: 16) {
            Button("打开 Sheet") { router.sheet(.modal) }
            Button("模拟通知（flush push）") {
                router.push(.notification(title: "新消息"), flush: true)
            }
            .buttonStyle(.borderedProminent)
            Text("先点「打开 Sheet」，再点「模拟通知」\n观察 Sheet 自动关闭后导航到通知页")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Home")
    }
}

struct FlushModalView: View {
    @Environment(IRouter<FlushRoute>.self) var router

    var body: some View {
        VStack(spacing: 16) {
            Text("Sheet 已展示").font(.title2)
            Button("关闭") { router.dismiss() }
        }
        .navigationTitle("Modal Sheet")
    }
}

struct FlushNotificationView: View {
    let title: String

    var body: some View {
        VStack {
            Image(systemName: "bell.fill").font(.largeTitle)
            Text(title).font(.title2)
        }
        .navigationTitle("通知详情")
    }
}
```

- [ ] **Step 7: 创建 TabDemo.swift**

演示多 Router 并存：每个 Tab 持有独立 IRouter，导航历史互不影响。

```swift
import SwiftUI
import iRouter

enum TabRoute: Hashable, Sendable {
    case feed
    case detail(id: Int)
    case profile
}

struct TabDemoView: View {
    @State private var tabARouter = IRouter<TabRoute>(root: .feed)
    @State private var tabBRouter = IRouter<TabRoute>(root: .profile)

    var body: some View {
        TabView {
            IRouterView(router: tabARouter) { route in
                switch route {
                case .feed:            TabFeedView(tabName: "Tab A")
                case .detail(let id):  TabDetailView(id: id)
                case .profile:         TabProfileView()
                }
            }
            .tabItem { Label("Tab A", systemImage: "house") }

            IRouterView(router: tabBRouter) { route in
                switch route {
                case .feed:            TabFeedView(tabName: "Tab B")
                case .detail(let id):  TabDetailView(id: id)
                case .profile:         TabProfileView()
                }
            }
            .tabItem { Label("Tab B", systemImage: "person") }
        }
    }
}

struct TabFeedView: View {
    @Environment(IRouter<TabRoute>.self) var router
    let tabName: String

    var body: some View {
        List(0..<5, id: \.self) { i in
            Button("\(tabName) — Item \(i)") {
                router.push(.detail(id: i))
            }
        }
        .navigationTitle(tabName)
    }
}

struct TabDetailView: View {
    @Environment(IRouter<TabRoute>.self) var router
    let id: Int

    var body: some View {
        VStack(spacing: 16) {
            Text("Detail #\(id)").font(.title)
            Button("Push Another") { router.push(.detail(id: id + 1)) }
            Button("Pop to Root") { router.popToRoot() }
        }
        .navigationTitle("Detail \(id)")
    }
}

struct TabProfileView: View {
    @Environment(IRouter<TabRoute>.self) var router

    var body: some View {
        VStack(spacing: 16) {
            Text("Profile").font(.title)
            Button("Push Detail") { router.push(.detail(id: 0)) }
        }
        .navigationTitle("Profile")
    }
}
```

- [ ] **Step 8: 在 Simulator 运行 Demo，验证四个场景**

在 Xcode 中选择 iOS 17+ Simulator，Run（⌘R）：
- Basic: push 多级、dedup、sheet 内 push、dismissAndPush ✓
- Filter: 未登录点 Profile → Login Sheet → 登录后再进 Profile ✓
- Flush: 打开 Sheet → 点模拟通知 → Sheet 消失，通知页出现 ✓
- Multi-Tab: Tab A / Tab B 独立导航，回退互不影响 ✓

- [ ] **Step 9: Commit**

```bash
git add demo/
git commit -m "feat: add iRouterDemo with Basic/Filter/Flush/Tab demos"
```

---

## Task 8：README

**Files:**
- Create: `README.md`

- [ ] **Step 1: 创建 README.md**

```markdown
# iRouter

A pure-SwiftUI router for iOS 17+. Type-safe enum routes, push/pop, sheet, fullScreenCover, filter chain, dedup, and flush — zero third-party dependencies.

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

**1. Define your routes**

```swift
import iRouter

enum AppRoute: Hashable, Sendable {
    case home
    case detail(id: String)
    case settings
    case login
}
```

**2. Create a Router and place IRouterView at the root**

```swift
@main
struct MyApp: App {
    @State private var router = IRouter<AppRoute>(root: .home)

    var body: some Scene {
        WindowGroup {
            IRouterView(router: router) { route in
                switch route {
                case .home:           HomeView()
                case .detail(let id): DetailView(id: id)
                case .settings:       SettingsView()
                case .login:          LoginView()
                }
            }
        }
    }
}
```

**3. Navigate from any child view**

```swift
struct HomeView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        VStack {
            Button("Detail")   { router.push(.detail(id: "42")) }
            Button("Settings") { router.sheet(.settings) }
        }
    }
}
```

## API Reference

### IRouter

```swift
@MainActor
@Observable
public final class IRouter<Route: Hashable & Sendable> {

    public init(root: Route, filters: [IRouterFilter<Route>] = [])

    // Push stack
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

### IRouterFilter

```swift
IRouterFilter { route, presentation in
    // auth guard
    if case .settings = route, !Auth.isLoggedIn {
        return .redirect(.login, .sheet)
    }
    return .allow
}
```

Filter results:

| Result | Behavior |
|---|---|
| `.allow` | Proceed with navigation |
| `.block` | Cancel navigation, do nothing |
| `.redirect(route, presentation)` | Navigate to another route instead |

### Parameters

`push(_:dedup:flush:)` / `sheet(_:flush:)` / `fullScreenCover(_:flush:)`:

| Parameter | Default | Description |
|---|---|---|
| `dedup` | `false` | Skip push if the same route is already at the top of the stack |
| `flush` | `false` | Dismiss all modals before navigating (for push notification / deep link scenarios) |

## Patterns

### With Filter (Auth Guard)

```swift
let router = IRouter<AppRoute>(
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
```

### Tab Bar (Independent Routers)

```swift
struct RootView: View {
    @State private var tabARouter = IRouter<AppRoute>(root: .home)
    @State private var tabBRouter = IRouter<AppRoute>(root: .feed)

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

### NavigationStack Above TabView (Single Router)

```swift
struct RootView: View {
    @State private var router = IRouter<AppRoute>(root: .tabs)

    var body: some View {
        IRouterView(router: router) { route in
            switch route {
            case .tabs:    MainTabView()        // TabView is inside
            case .detail:  DetailView()         // Push hides tab bar
            }
        }
    }
}
```

### Notification / Deep Link (flush)

```swift
// On receiving a push notification
router.push(.orderDetail(id: notificationId), flush: true)
// Any presented sheet or cover is dismissed automatically first
```

### Navigate from Sheet Back to Main Stack

```swift
// Inside a sheet view
Button("Go to Detail (close sheet + push)") {
    router.dismissAndPush(.detail(id: "42"))
}
```

## Edge-Case Behavior

| Scenario | Behavior |
|---|---|
| `pop()` on empty path | No-op, no crash |
| `dismiss()` with no modals and empty path | No-op, no crash |
| `dedup: true` with matching top route | Push skipped |
| `flush: true` | All modals dismissed, then navigation executes |
| Sheet/Cover internal push | Independent stack, doesn't affect parent path |
| Filter `.redirect` to blocked route | Redirect also runs through Filter chain; caller must avoid cycles |

## Out of Scope

- **URL / Deep Link parsing** — Map URLs to routes in your app layer using `onOpenURL`
- **Alert / ConfirmationDialog** — Ephemeral UI state, not a navigation destination
- **Cross-tab stack coordination** — Build an `AppCoordinator` that combines tab selection + per-tab `IRouter`
- **Custom transition animations** — SwiftUI NavigationStack transitions are limited on iOS 17; planned for v2
- **macOS / tvOS / watchOS**
- **Back gesture interception** — No public SwiftUI API available

## Demo

Open `demo/iRouterDemo.xcodeproj`, select a simulator and run. Includes:

- **Basic** — push / pop / sheet / cover / dedup / dismissAndPush
- **Filter** — auth guard redirect to login sheet
- **Flush** — simulate notification dismissing sheet then navigating
- **Multi-Tab** — two independent routers with separate back stacks
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README for iRouter"
```

---

## 自检结果

**Spec coverage:**
- ✅ Push / Pop / PopToRoot — Task 3
- ✅ Sheet (内部导航栈) — Task 4 + IRouterView 的 .sheet(item:)
- ✅ FullScreenCover (内部导航栈) — Task 4 + IRouterView 的 .fullScreenCover(item:)
- ✅ dismissAndPush — Task 4
- ✅ Filter 拦截链 allow/block/redirect — Task 5
- ✅ dedup — Task 3
- ✅ flush — Task 3 (path) + Task 4 (modal)
- ✅ 子 Router 继承 Filter — Task 5 (测试: childRouterInheritsFilters)
- ✅ IRouterView @Environment 注入 — Task 6
- ✅ 多 Router 并存 — Task 7 TabDemo
- ✅ 所有 Out of Scope 项在 README 明确说明

**Type consistency:**
- `IRouterFilter<Route>.Result` 贯穿 Task 2/5 ✓
- `IRouterContext<Route>` 在 Task 2 定义，Task 3/4 测试中直接构造 ✓
- `runFilters(route:presentation:)` 仅在 Task 5 引入，后续 Task 未再修改 ✓
- `clearModals()` 在 Task 3 引入，Task 4 沿用 ✓
