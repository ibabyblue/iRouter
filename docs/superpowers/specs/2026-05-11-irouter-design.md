# iRouter 设计文档

**日期**：2026-05-11  
**状态**：待实现  
**平台**：iOS 17+，Swift 6.0，零第三方依赖

---

## 一、背景与目标

iRouter 是 `ios_modules` 系列的路由 SPM 包，与 iBanner、iTabPager 同属一个包家族。

**目标**：提供一套纯 SwiftUI、类型安全、调用简单的路由系统，覆盖 Push、Sheet、FullScreenCover 三种导航模式，并内置拦截器链、去重和 flush 机制。

---

## 二、边界

### 能做（In Scope）

| 能力 | 说明 |
|---|---|
| Push / Pop / PopToRoot | NavigationStack 栈操作 |
| Sheet | 半模态，内置独立导航栈（子 Router） |
| FullScreenCover | 全屏模态，内置独立导航栈（子 Router） |
| dismissAndPush | 关闭所有模态后 push |
| Filter 拦截链 | 放行 / 拦截 / 重定向，支持登录保护、埋点等 |
| dedup 去重 | 防止栈顶重复入栈 |
| flush 模式 | 清理所有模态后再导航，适合通知/深链唤起场景 |
| 子 Router 自动创建 | sheet/cover 内部自动获得独立导航栈 |
| Filter 继承 | 子 Router 继承父 Router 的 Filter 链 |
| 多 Router 并存 | 调用方可创建多个 IRouter 实例（如每个 Tab 一个） |

### 不做（Out of Scope）

| 不做的事 | 原因 |
|---|---|
| URL / 深链接解析 | URL → Route 映射是 App 层职责，用 `onOpenURL` + 自定义解析 |
| Alert / ConfirmationDialog | 属于临时 UI 状态，不是导航目的地 |
| Tab 间跨栈协调 | App 级 Coordinator 职责，iRouter 提供积木由调用方组合 |
| 自定义转场动画 | iOS 17 SwiftUI 对 NavigationStack 转场支持有限，留 v2 |
| macOS / tvOS / watchOS | 仅支持 iOS 17+ |
| 后退手势拦截 | 系统行为，SwiftUI 无公开 API 干预 |
| 路由埋点/日志 | 通过 Filter 链自行实现，包不内置 |

---

## 三、架构

### 分层结构

```
┌─────────────────────────────────────────┐
│            调用方 App                    │
│  ┌──────────────────────────────────┐   │
│  │  IRouterView<Route, Content>     │   │  ← 唯一入口 View
│  │  ┌────────────────────────────┐  │   │
│  │  │  NavigationStack           │  │   │
│  │  │  (path: $router.path)      │  │   │
│  │  └────────────────────────────┘  │   │
│  │  .sheet / .fullScreenCover       │   │
│  └──────────────────────────────────┘   │
│          ↕  @Environment                │
│  ┌──────────────────────────────────┐   │
│  │  IRouter<Route>  @Observable     │   │  ← 状态核心
│  │  ┌──────────┐ ┌────────────────┐ │   │
│  │  │  path    │ │ sheetContext   │ │   │
│  │  │ [Route]  │ │ coverContext   │ │   │
│  │  └──────────┘ └────────────────┘ │   │
│  └──────────────────────────────────┘   │
│          ↕                              │
│  ┌──────────────────────────────────┐   │
│  │  [IRouterFilter<Route>]          │   │  ← 拦截器链
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### 公开类型一览

| 类型 | 职责 |
|---|---|
| `IRouter<Route>` | 状态持有者，所有导航操作的入口 |
| `IRouterView<Route, Content>` | SwiftUI 容器，驱动 NavigationStack + 模态呈现 |
| `IRouterFilter<Route>` | 拦截器，跳转前执行 |
| `IRouterPresentation` | 导航方式枚举：push / sheet / fullScreenCover |
| `IRouterContext<Route>` | sheet/cover 的呈现上下文，持有子 Router |

---

## 四、核心组件 API

### `IRouter<Route>`

```swift
@MainActor
@Observable
public final class IRouter<Route: Hashable & Sendable> {

    public let root: Route
    public var path: [Route] = []
    public var sheetContext: IRouterContext<Route>? = nil
    public var coverContext: IRouterContext<Route>? = nil

    public init(root: Route, filters: [IRouterFilter<Route>] = [])

    // Push 栈
    public func push(_ route: Route, dedup: Bool = false, flush: Bool = false)
    public func pop()
    public func popToRoot()

    // 模态
    public func sheet(_ route: Route, flush: Bool = false)
    public func fullScreenCover(_ route: Route, flush: Bool = false)
    public func dismiss()
    public func dismissAndPush(_ route: Route)
}
```

**约束**：Route 必须满足 `Hashable & Sendable`。推荐使用 enum，关联值也需满足同等约束。

### `IRouterContext<Route>`

```swift
public final class IRouterContext<Route: Hashable & Sendable>: Identifiable {
    public let id = UUID()
    public let route: Route
    public let childRouter: IRouter<Route>
}
```

`Identifiable` 供 `.sheet(item:)` / `.fullScreenCover(item:)` 驱动呈现。子 Router 继承父 Router 的 Filter 链。

### `IRouterFilter<Route>`

```swift
public struct IRouterFilter<Route: Hashable & Sendable>: Sendable {

    public enum Result: Sendable {
        case allow
        case block
        case redirect(Route, IRouterPresentation)
    }

    public init(_ handler: @Sendable @escaping (Route, IRouterPresentation) -> Result)
}

public enum IRouterPresentation: Sendable {
    case push
    case sheet
    case fullScreenCover
}
```

### `IRouterView<Route, Content>`

```swift
public struct IRouterView<Route: Hashable & Sendable, Content: View>: View {
    public init(
        router: IRouter<Route>,
        @ViewBuilder destination: @escaping (Route) -> Content
    )
}
```

`destination` 闭包处理所有路由（含 root），在 NavigationStack 的根视图和 `navigationDestination` 中复用同一 builder。

---

## 五、数据流与行为细节

### Push 执行流

```
router.push(.detail(id: "42"), dedup: true, flush: false)
        │
        ▼
① flush 检查
   flush == true → coverContext = nil, sheetContext = nil → 继续
        │
        ▼
② Filter 链（按注册顺序，遇到 block/redirect 立即终止）
   .allow     → 继续
   .block     → 终止，不跳转
   .redirect(to, presentation) → 以指定方式导航到 to，redirect 本身也过一遍 Filter 链
        │
        ▼
③ dedup 检查
   dedup == true && path.last == route → 忽略
        │
        ▼
④ path.append(route)
   @Observable 触发 IRouterView 更新 → NavigationStack 渲染新页面
```

### Sheet / Cover 执行流

```
router.sheet(.login)
        │
        ▼
① flush + Filter 链（presentation 为 .sheet）
        │
        ▼
② childRouter = IRouter(root: .login, filters: 父Router的filters)
        │
        ▼
③ sheetContext = IRouterContext(route: .login, childRouter: childRouter)
   IRouterView 的 .sheet(item: $router.sheetContext) 触发呈现
   Sheet 内部是独立 IRouterView(router: childRouter)
```

### dismiss 优先级

```swift
// cover > sheet > pop
func dismiss() {
    if coverContext != nil { coverContext = nil; return }
    if sheetContext != nil { sheetContext = nil; return }
    if !path.isEmpty       { path.removeLast() }
}
```

### dismissAndPush

先关闭所有模态，再以 `.push` 方式执行一次完整的导航流（包含 Filter 链和 dedup 检查）。

```swift
func dismissAndPush(_ route: Route) {
    coverContext = nil
    sheetContext = nil
    push(route)   // 经过完整 Filter 链
}
```

### dedup 语义

只检查栈顶（`path.last == route`）。不影响栈中间层相同路由（A→B→A 是合法场景）。

### flush 语义

将 `sheetContext` 和 `coverContext` 置 `nil` 后再执行导航，SwiftUI 自动收起模态动画。适用于推送通知点击、Universal Link 唤起等需要从干净状态导航的场景。

### Filter redirect 细节

命中 `.redirect` 后终止当前 Filter 链，以指定 presentation 导航到目标路由，该次导航同样过 Filter 链。调用方需确保重定向目标不产生循环。

---

## 六、完整调用示例

```swift
// 1. 定义路由
enum AppRoute: Hashable, Sendable {
    case home
    case detail(id: String)
    case settings
    case login
}

// 2. 创建 Router（带拦截器）
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

// 3. 放置 IRouterView（视图树根部）
IRouterView(router: router) { route in
    switch route {
    case .home:           HomeView()
    case .detail(let id): DetailView(id: id)
    case .settings:       SettingsView()
    case .login:          LoginView()
    }
}

// 4. 子 View 内使用
struct HomeView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        Button("详情") { router.push(.detail(id: "42")) }
        Button("设置") { router.push(.settings) }         // 未登录自动重定向 login sheet
        Button("通知唤起") { router.push(.detail(id: "99"), flush: true) }
    }
}

// 5. Tab Bar 场景（两个独立 Router）
struct RootView: View {
    @State var tabARouter = IRouter<AppRoute>(root: .home)
    @State var tabBRouter = IRouter<AppRoute>(root: .feed)

    var body: some View {
        TabView {
            IRouterView(router: tabARouter) { ... }.tabItem { ... }
            IRouterView(router: tabBRouter) { ... }.tabItem { ... }
        }
    }
}
```

---

## 七、测试策略

单元测试位于 `Tests/iRouterTests/`，覆盖以下场景：

| 测试场景 | 验证点 |
|---|---|
| push / pop / popToRoot | path 数组状态正确变化 |
| dedup | 栈顶相同路由不重复入栈 |
| flush | 调用前有 sheet/cover 时被正确清除 |
| sheet / dismiss | sheetContext 创建与清空 |
| cover / dismiss | coverContext 创建与清空 |
| dismissAndPush | 模态清除 + path 追加 |
| Filter allow | 路由正常执行 |
| Filter block | path/context 不变 |
| Filter redirect | 跳转到重定向目标 |
| Filter 链顺序 | 首个 block/redirect 终止链 |
| 子 Router 继承 Filter | sheet 内部导航过父 Filter 链 |

不测试：View 层渲染、转场动画视觉效果。

---

## 八、项目结构

```
iRouter/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── iRouter/
│       ├── IRouter.swift
│       ├── IRouterView.swift
│       ├── IRouterFilter.swift
│       ├── IRouterPresentation.swift
│       └── IRouterContext.swift
├── Tests/
│   └── iRouterTests/
│       └── IRouterTests.swift
└── demo/
    ├── iRouterDemo.xcodeproj
    └── iRouterDemo/
        ├── iRouterDemoApp.swift
        ├── ContentView.swift
        ├── BasicDemo.swift          ← push/pop/sheet/cover
        ├── FilterDemo.swift         ← 登录拦截 + 重定向
        ├── FlushDemo.swift          ← flush 模拟通知唤起
        └── TabDemo.swift            ← 多 Router + Tab Bar
```
