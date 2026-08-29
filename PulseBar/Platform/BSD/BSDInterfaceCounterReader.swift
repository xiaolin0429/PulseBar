import Darwin

public struct BSDInterfaceCounterReader: NetworkRawReading {
    public init() {}

    public func readInterfaceCounters() throws -> [InterfaceCounter] {
        var firstAddress: UnsafeMutablePointer<ifaddrs>?
        let result = getifaddrs(&firstAddress)
        guard result == 0, let firstAddress else {
            throw SystemMetricReadError.systemCall(function: "getifaddrs", code: errno)
        }
        defer { freeifaddrs(firstAddress) }

        var counters: [String: InterfaceCounter] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let address = cursor {
            defer { cursor = address.pointee.ifa_next }
            guard let socketAddress = address.pointee.ifa_addr,
                  Int32(socketAddress.pointee.sa_family) == AF_LINK,
                  let rawData = address.pointee.ifa_data else {
                continue
            }

            let name = String(cString: address.pointee.ifa_name)
            let flags = Int32(bitPattern: address.pointee.ifa_flags)
            let data = rawData.assumingMemoryBound(to: if_data.self).pointee
            counters[name] = InterfaceCounter(
                name: name,
                receivedBytes: UInt64(data.ifi_ibytes),
                sentBytes: UInt64(data.ifi_obytes),
                isUp: flags & IFF_UP != 0,
                isRunning: flags & IFF_RUNNING != 0,
                isLoopback: flags & IFF_LOOPBACK != 0
            )
        }

        return counters.values.sorted { $0.name < $1.name }
    }
}
