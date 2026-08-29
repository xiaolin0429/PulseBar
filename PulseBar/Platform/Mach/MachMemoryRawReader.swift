import Darwin

public struct MachMemoryRawReader: MemoryRawReading {
    public init() {}

    public func readVMStatistics() throws -> RawVMStatistics {
        var pageSize: vm_size_t = 0
        let pageResult = host_page_size(mach_host_self(), &pageSize)
        guard pageResult == KERN_SUCCESS else {
            throw SystemMetricReadError.systemCall(function: "host_page_size", code: pageResult)
        }

        var statistics = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let statisticsResult = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard statisticsResult == KERN_SUCCESS else {
            throw SystemMetricReadError.systemCall(function: "host_statistics64", code: statisticsResult)
        }

        return RawVMStatistics(
            pageSize: UInt64(pageSize),
            freePages: UInt64(statistics.free_count),
            activePages: UInt64(statistics.active_count),
            inactivePages: UInt64(statistics.inactive_count),
            speculativePages: UInt64(statistics.speculative_count),
            wiredPages: UInt64(statistics.wire_count),
            compressedPages: UInt64(statistics.compressor_page_count),
            purgeablePages: UInt64(statistics.purgeable_count)
        )
    }

    public func readSwapUsage() throws -> RawSwapUsage? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard result == 0 else {
            throw SystemMetricReadError.systemCall(function: "sysctlbyname(vm.swapusage)", code: errno)
        }
        return RawSwapUsage(
            totalBytes: usage.xsu_total,
            usedBytes: usage.xsu_used,
            freeBytes: usage.xsu_avail
        )
    }
}
