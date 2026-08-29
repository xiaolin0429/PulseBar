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
}
