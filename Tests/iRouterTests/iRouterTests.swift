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
