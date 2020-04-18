import XCTest
import Dustpan

fileprivate func dup<T>(_ x: T) -> (T, T) {
    return (x, x)
}

final class DustpanTests: XCTestCase {
    func testCycles() {
        gc()
        XCTAssertEqual(gcInfo().total, 0)
        XCTAssertEqual(Cnt.total, 0)

        let n1 = RootNode()
        let n2 = Node()
        let n3 = Node()
        let n4 = Node()
        n1.next = [n2, n2]
        n2.next = [n3, n4]
        n3.next = [n4]
        XCTAssertEqual(gcInfo().pinned, 1)
        XCTAssertFalse(analyzeObjectGraph(dup(n1)).isCyclic)

        n4.next = [n1]
        XCTAssert(analyzeObjectGraph(dup(n1)).isCyclic)

        n4.next = []
        XCTAssertFalse(analyzeObjectGraph(dup(n1)).isCyclic)


        n4.next = [n4]
        gc()
        XCTAssertEqual(gcInfo().total, 4)
        XCTAssert(analyzeObjectGraph(n1).isCyclic)

        n4.next = [n4, n2]
        gc()
        XCTAssertEqual(gcInfo().total, 4)
        XCTAssert(analyzeObjectGraph(n1).isCyclic)
        XCTAssert(analyzeObjectGraph(n2).isCyclic)
        XCTAssert(analyzeObjectGraph(n3).isCyclic)
        XCTAssert(analyzeObjectGraph(n4).isCyclic)

        n1.next = []
        gc()
        XCTAssertEqual(gcInfo().total, 1)
        XCTAssertFalse(analyzeObjectGraph(n1).isCyclic)
        XCTAssertFalse(analyzeObjectGraph(n2).isCyclic)
        XCTAssertFalse(analyzeObjectGraph(n3).isCyclic)
        XCTAssertFalse(analyzeObjectGraph(n4).isCyclic)
    }

    func testDealloc() {
        gc()
        XCTAssertEqual(gcInfo().total, 0)
        XCTAssertEqual(Cnt.total, 0)

        var n1: NodeProtocol! = RootNode()
        var n2: NodeProtocol! = Node()
        var n3: NodeProtocol! = Node()
        n1.next = [n2]
        n2.next = [n3]
        n3.next = [n2]

        n2 = nil
        n3 = nil
        gc()
        XCTAssertEqual(gcInfo().total, 3)
        XCTAssertEqual(Cnt.total, 3)

        n1 = nil
        XCTAssertEqual(Cnt.total, 2)
        gc()
        XCTAssertEqual(gcInfo().total, 0)
        XCTAssertEqual(Cnt.total, 0)
    }

    func testExample() {
        gc()
        XCTAssertEqual(gcInfo().total, 0)

        let app = MyApp()

        app.makeCyclicList()
        gc()
        XCTAssertEqual(gcInfo().total, 5)
        app.makeCyclicList()
        app.makeCyclicList()
        XCTAssertEqual(Cnt.total, 12)
        gc()
        XCTAssertEqual(Cnt.total, 4)
        XCTAssertEqual(gcInfo().total, 5)
        XCTAssertEqual(gcInfo().pinned, 1)
        XCTAssert(analyzeObjectGraph(app).isCyclic)

        app.list = nil
        gc()
        XCTAssertEqual(Cnt.total, 0)
        XCTAssertEqual(gcInfo().total, 1)
        XCTAssertEqual(gcInfo().pinned, 1)
        XCTAssertFalse(analyzeObjectGraph(app).isCyclic)
    }

    static var allTests = [
        ("testCycles", testCycles),
        ("testDealloc", testDealloc),
        ("testExample", testExample),
    ]
}
