public struct RingBuffer<Element: Sendable>: Sendable {
    private var storage: [Element?]
    private var writeIndex = 0
    public private(set) var count = 0

    public init(capacity: Int) {
        precondition(capacity > 0)
        storage = Array(repeating: nil, count: capacity)
    }

    public var capacity: Int { storage.count }

    public mutating func append(_ element: Element) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    public func elements() -> [Element] {
        guard count > 0 else { return [] }
        let start = count == capacity ? writeIndex : 0
        return (0..<count).compactMap { offset in
            storage[(start + offset) % capacity]
        }
    }

    /// 清空元素并重置写入位置，环形缓存容量保持不变。
    /// - Parameter keepingCapacity: 当前实现始终保留逻辑容量，该参数不会改变行为。
    public mutating func removeAll(keepingCapacity: Bool = true) {
        storage = Array(repeating: nil, count: capacity)
        writeIndex = 0
        count = 0
    }
}
