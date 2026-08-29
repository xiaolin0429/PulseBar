import Darwin

public struct MachCPURawReader: CPURawReading {
    public init() {}

    public func readTicks() throws -> [CPUTickCounter] {
        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let processorInfo else {
            throw SystemMetricReadError.systemCall(function: "host_processor_info", code: result)
        }

        defer {
            let byteCount = vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: processorInfo), byteCount)
        }

        let statesPerProcessor = Int(CPU_STATE_MAX)
        guard processorInfoCount >= processorCount * natural_t(statesPerProcessor) else {
            throw SystemMetricReadError.malformedData(source: "host_processor_info")
        }

        return (0..<Int(processorCount)).map { index in
            let base = index * statesPerProcessor
            return CPUTickCounter(
                user: UInt64(UInt32(bitPattern: processorInfo[base + Int(CPU_STATE_USER)])),
                system: UInt64(UInt32(bitPattern: processorInfo[base + Int(CPU_STATE_SYSTEM)])),
                nice: UInt64(UInt32(bitPattern: processorInfo[base + Int(CPU_STATE_NICE)])),
                idle: UInt64(UInt32(bitPattern: processorInfo[base + Int(CPU_STATE_IDLE)]))
            )
        }
    }
}
