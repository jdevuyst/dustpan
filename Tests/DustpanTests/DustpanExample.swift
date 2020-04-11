import Dustpan

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
    var list: LL<Int>? = nil

    func makeCyclicList() {
        let last = LL(4)
        let first = LL(1, LL(2, LL(3, last)))
        last.next = first
        list = first
    }
}
