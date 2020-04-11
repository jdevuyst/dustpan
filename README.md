# Dustpan

Dustpan is a small library that adds optional garbage collection to Swift.

## Rationale

One of the features that sets the [Swift programming language](https://swift.org) apart from other languages is its use of [Automatic Reference Counting (ARC)](https://docs.swift.org/swift-book/LanguageGuide/AutomaticReferenceCounting.html). Many other modern programming languages use [Garbage Collection (GC)](https://en.wikipedia.org/wiki/Garbage_collection_(computer_science)) instead.

Both ARC and GC are forms of automatic memory management. Memory that is no longer reachable from the running application is automatically freed. However, ARC has a limitation in that it cannot free [object graphs](https://stackoverflow.com/questions/2046761/what-is-object-graph-in-java) that contain [strong reference cycles](https://docs.swift.org/swift-book/LanguageGuide/AutomaticReferenceCounting.html#ID52). In ARC, such cycles must be broken manually before they become unreachable.

Whereas ARC has its advantages (e.g. deterministic performance), there are problem domains where GC is very handy. Consider, for example, the case where you want to [transpile](https://www.stevefenton.co.uk/2012/11/compiling-vs-transpiling/) a garbage collected programming language to Swift.

## Performance

Dustpan was developed entirely in Swift and uses the Swift reflection API to walk the object graph. The specific GC algorithm used is [Mark and Sweep](https://www.geeksforgeeks.org/mark-and-sweep-garbage-collection-algorithm/).

Dustpan is mostly a toy project and its real world performance has not been analyzed. It should be expected to be quite slow.

## Usage

Here's an example:

```swift
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
```

There are three things you need to do to adopt Dustpan:

1. Use a `Ref(root: true)` annotation to flag object graphs that should be garbage collected.
2. Inside the garbage collected object graphs, use a `Ref` annotation to break strong reference cycles.
3. Periodically, call `gc()` to free unreachable memory.

Do note that:

- Dustpan uses a [stop-the-world algorithm](https://stackoverflow.com/questions/40182392/does-java-garbage-collect-always-has-to-stop-the-world). Therefore, while `gc` is running, there should be no mutations in the object graphs that are reachable from root references.
- If you run into a “Fatal error: Unexpectedly found nil while unwrapping an Optional value” inside a `Ref`, this means that `gc` freed that particular `Ref` because there was no `Ref(root: true)`  pointing to that part of the program. The fix is to add the missing `Ref(root: true)` annotation.
