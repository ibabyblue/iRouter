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
}
