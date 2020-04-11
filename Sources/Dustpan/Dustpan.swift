// MARK: Internals

/// Walk the object graph starting at `origin` and call `onFound` for each value of type `T`.
///
/// Note that this function does not walk past values of type `T`.
///
/// `findClosest` will fail if it encounters a reference cycle.
fileprivate func findClosest<T>(origin: Any, onFound: (T) -> Void) {
    var todo = [origin]

    while let x = todo.popLast() {
        for (_, y) in Mirror(reflecting: x).children {
            if let z = y as? T {
                onFound(z)
            } else {
                todo.append(y)
            }
        }
    }
}

/// Facts about the current state of the garbage collector.
public struct GCInfo {
    /// Total number of `Ref`s that were instantiated but have not yet been collected by `gc`.
    public let total: Int

    /// Number of 'pinned' reference.
    /// In normal usage, this counts the number of `Ref(root: true)` uses.
    public let pinned: Int
}

/// Garbage collected reference.
fileprivate final class PrimRef {
    typealias Identifier = UnsafeMutableRawPointer

    /// A unique identifier for this `PrimRef` instance.
    var identifier: Identifier {
        return Unmanaged.passUnretained(self).toOpaque()
    }

    /// All `PrimRef` instances.
    private static var all: [Identifier: PrimRef] = [:]

    /// All 'pinned' `PrimRef` instances.
    private static var pinned: [Identifier: PrimRef] = [:]

    /// The value that this reference points to.
    ///
    /// This value is non-nil initially and is only mutated when the reference is freed by `gc`, at which point it is nil.
    ///
    /// If a program crashes here, that should mean that `gc` freed this reference because no pinned/root reference
    /// was pointing to this part of the program.
    private(set) var wrappedValue: Any!

    init(wrappedValue: Any) {
        self.wrappedValue = wrappedValue
        PrimRef.all[identifier] = self
    }

    /// Whether or not this reference is a 'pinned' reference.
    ///
    /// Pinned references are the starting point for `gc` and are never freed.
    ///
    /// To prevent non-pinned references from being freed, they should be reachable from pinned references,
    /// which should be reachable from the running applications.
    var isPinned: Bool {
        get { PrimRef.pinned[identifier] != nil }
        set { PrimRef.pinned[identifier] = newValue ? self : nil }
    }

    static func gcInfo() -> GCInfo {
        return GCInfo(total: all.count,
                      pinned: pinned.count)
    }

    /// Start mark-and-sweep.
    ///
    /// The world must be stopped while this function is running.
    static func gc() {
        var seen: Set<PrimRef.Identifier> = Set(PrimRef.pinned.keys)
        var todo: [PrimRef] = Array(PrimRef.pinned.values)

        while let known = todo.popLast() {
            findClosest(origin: known) { (found: PrimRef) in
                if !seen.contains(found.identifier) {
                    seen.insert(found.identifier)
                    todo.append(found)
                }
            }
        }

        PrimRef.all = PrimRef.all.filter { (ident, ref) in
            let keep = seen.contains(ident)
            if !keep {
                ref.wrappedValue = nil
            }
            return keep
        }
    }
}

/// `AutoRef` is a wrapper for `PrimRef` that is typed and that automatically manages pinning.
///
/// Upon deallocation, `AutoRef` unpins the wrapped `PrimRef`.
/// That is to say, it substitutes a notion of 'root reference' for the more primitive concept of a 'pinned reference'.
fileprivate final class AutoRef<T> {
    var primRef: PrimRef {
        didSet {
            primRef.isPinned = oldValue.isPinned
            oldValue.isPinned = false
        }
    }

    init(wrappedValue: T, root: Bool) {
        primRef = PrimRef(wrappedValue: wrappedValue)
        primRef.isPinned = root
    }

    var wrappedValue: T {
        get { primRef.wrappedValue as! T }
        set { primRef = PrimRef(wrappedValue: newValue) }
    }

    var isRoot: Bool {
        get { primRef.isPinned }
        set { primRef.isPinned = newValue }
    }

    deinit {
        primRef.isPinned = false
    }
}

// MARK: Public API

/// A `Ref` is a reference (pointer) that is managed by `gc`.
@propertyWrapper
public struct Ref<T> {
    private var ref: AutoRef<T>

    public init(wrappedValue: T, root: Bool = false) {
        ref = AutoRef(wrappedValue: wrappedValue, root: root)
    }

    public var wrappedValue: T {
        get { ref.wrappedValue }
        set { ref.wrappedValue = newValue }
    }

    public var isRoot: Bool {
        get { ref.isRoot }
        set { ref.isRoot = newValue }
    }
}

/// Call `gc` (periodicially) to clean memory.
///
/// Dustpan uses a [stop-the-world algorithm](https://stackoverflow.com/questions/40182392/does-java-garbage-collect-always-has-to-stop-the-world).
/// Therefore, while `gc` is running, there should be no mutations in the object graphs that are reachable from root references.
public func gc() {
    PrimRef.gc()
}

/// Returns facts about the current state of the garbage collector.
///
/// This function is provided to help with debugging and testing.
///
/// Note that the numbers will make more sense when `gcInfo` is called right after invoking `gc`.
public func gcInfo() -> GCInfo {
    PrimRef.gcInfo()
}
