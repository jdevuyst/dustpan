public struct ObjectGraphInfo {
    var objects: [UnsafeMutableRawPointer: AnyObject] = [:]

    var isCyclic = false

    mutating func merge(_ other: ObjectGraphInfo) {
        objects.merge(other.objects, uniquingKeysWith: {_, y in y})
        isCyclic = isCyclic || other.isCyclic
    }
}

fileprivate func analyizeObjectGraphPrim(start: Any, info: ObjectGraphInfo) -> ObjectGraphInfo {
    precondition(!info.isCyclic)

    var info = info

    let obj = start as AnyObject
    if type(of: start) == type(of: obj) {
        let ident = Unmanaged.passUnretained(obj).toOpaque()
        if info.objects[ident] != nil {
            info.isCyclic = true
        } else {
            info.objects[ident] = obj
        }
    }

    guard !info.isCyclic else { return info }

    let frozenInfo = info
    for (_, c) in Mirror(reflecting: start).children {
        info.merge(analyizeObjectGraphPrim(start: c, info: frozenInfo))
    }

    return info
}

public func analyzeObjectGraph(_ start: Any) -> ObjectGraphInfo {
    return analyizeObjectGraphPrim(start: start, info: ObjectGraphInfo())
}
