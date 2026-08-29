import Darwin
import Foundation
import PulseBarCore

@main
struct PerformanceProbe {
    private struct Result {
        let name: String
        let p50Milliseconds: Double
        let p95Milliseconds: Double
        let maximumMilliseconds: Double
        let budgetMilliseconds: Double

        var passed: Bool { p95Milliseconds <= budgetMilliseconds }
    }

    static func main() {
        let iterations = parsedIterations()
        print("PulseBar collector benchmark (\(iterations) iterations)")

        let cpuReader = MachCPURawReader()
        let memoryReader = MachMemoryRawReader()
        let networkReader = BSDInterfaceCounterReader()
        let diskReader = IOKitDiskRawReader()
        let volumeReader = VolumeCapacityRawReader()

        do {
            let results = try [
                measure("CPU raw", iterations: iterations, budget: 3) {
                    _ = try cpuReader.readTicks()
                },
                measure("Memory raw", iterations: iterations, budget: 3) {
                    _ = try memoryReader.readVMStatistics()
                    _ = try memoryReader.readSwapUsage()
                },
                measure("Network counters", iterations: iterations, budget: 3) {
                    _ = try networkReader.readInterfaceCounters()
                },
                measure("Disk I/O counters", iterations: iterations, budget: 8) {
                    _ = try diskReader.readDeviceCounters()
                },
                measure("Volume capacity", iterations: iterations, budget: 20) {
                    _ = try volumeReader.readVolumes()
                }
            ]

            for result in results {
                print(
                    "\(result.passed ? "PASS" : "FAIL") \(result.name): " +
                    "p50=\(format(result.p50Milliseconds)) ms, " +
                    "p95=\(format(result.p95Milliseconds)) ms, " +
                    "max=\(format(result.maximumMilliseconds)) ms, " +
                    "budget=\(format(result.budgetMilliseconds)) ms"
                )
            }
            if results.contains(where: { !$0.passed }) {
                exit(EXIT_FAILURE)
            }
        } catch {
            fputs("FAIL benchmark source unavailable: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func measure(
        _ name: String,
        iterations: Int,
        budget: Double,
        operation: () throws -> Void
    ) throws -> Result {
        for _ in 0..<5 {
            try operation()
        }

        let clock = ContinuousClock()
        var durations: [Double] = []
        durations.reserveCapacity(iterations)
        for _ in 0..<iterations {
            let started = clock.now
            try operation()
            durations.append(started.duration(to: clock.now).milliseconds)
        }
        durations.sort()
        return Result(
            name: name,
            p50Milliseconds: percentile(0.50, values: durations),
            p95Milliseconds: percentile(0.95, values: durations),
            maximumMilliseconds: durations.last ?? 0,
            budgetMilliseconds: budget
        )
    }

    private static func percentile(_ percentile: Double, values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let index = min(
            values.count - 1,
            max(0, Int(ceil(Double(values.count) * percentile)) - 1)
        )
        return values[index]
    }

    private static func parsedIterations() -> Int {
        guard let index = CommandLine.arguments.firstIndex(of: "--iterations"),
              CommandLine.arguments.indices.contains(index + 1),
              let value = Int(CommandLine.arguments[index + 1]) else {
            return 120
        }
        return min(10_000, max(20, value))
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }
}

private extension Duration {
    var milliseconds: Double {
        let parts = components
        return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
    }
}
