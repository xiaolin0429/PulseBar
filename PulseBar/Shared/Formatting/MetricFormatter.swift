import Foundation

public enum MetricFormatter {
    public static func bytes(
        _ value: UInt64,
        unitSystem: UnitSystem = .mixedDefault
    ) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(clamping: value),
            countStyle: unitSystem == .decimal ? .decimal : .binary
        )
    }

    public static func bytesPerSecond(
        _ value: Double,
        unitSystem: UnitSystem = .mixedDefault
    ) -> String {
        guard value.isFinite, value >= 0 else { return "—" }
        let style: ByteCountFormatter.CountStyle = unitSystem == .binary ? .binary : .decimal
        return "\(ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: style))/s"
    }

    public static func compactBytes(
        _ value: UInt64,
        unitSystem: UnitSystem = .mixedDefault
    ) -> String {
        let base = unitSystem == .decimal ? 1_000.0 : 1_024.0
        return compactMagnitude(Double(value), base: base)
    }

    public static func compactBytesPerSecond(
        _ value: Double,
        unitSystem: UnitSystem = .mixedDefault
    ) -> String {
        guard value.isFinite, value >= 0 else { return "—" }
        let base = unitSystem == .binary ? 1_024.0 : 1_000.0
        return "\(compactMagnitude(value, base: base))/s"
    }

    private static func compactMagnitude(_ value: Double, base: Double) -> String {
        let suffixes = ["B", "K", "M", "G", "T", "P"]
        var scaled = max(value, 0)
        var suffixIndex = 0

        while scaled >= base, suffixIndex < suffixes.count - 1 {
            scaled /= base
            suffixIndex += 1
        }

        if scaled >= 999.5, suffixIndex == suffixes.count - 1 {
            return "999P+"
        }

        var number = compactNumber(scaled)
        if number == String(Int(base)), suffixIndex < suffixes.count - 1 {
            scaled /= base
            suffixIndex += 1
            number = compactNumber(scaled)
        }
        return number + suffixes[suffixIndex]
    }

    private static func compactNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if value >= 10 || abs(value - rounded) < 0.05 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
