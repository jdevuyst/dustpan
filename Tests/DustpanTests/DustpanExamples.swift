import Dustpan

class Cnt {
    static var total = 0

    init() { Cnt.total += 1 }

    deinit { Cnt.total -= 1 }
}

// MARK: - Linked Lists

class LL<T> {
    var value: T

    @Ref
    var next: LL<T>?

    init(_ value: T, _ next: LL<T>? = nil) {
        self.value = value
        self.next = next
    }
}

class MyApp {
    @Ref(root: true)
    var list: LL<Cnt>? = nil

    func makeCyclicList() {
        let last = LL(Cnt())
        let first = LL(Cnt(), LL(Cnt(), LL(Cnt(), last)))
        last.next = first
        list = first
    }
}

// MARK: - Trees

protocol NodeProtocol {
    var next: [NodeProtocol] { get set }
}

class Node: NodeProtocol {
    @Ref
    var next: [NodeProtocol] = []

    let cnt = Cnt()
}

class RootNode: NodeProtocol {
    @Ref(root: true)
    var next: [NodeProtocol] = []

    let cnt = Cnt()
}
