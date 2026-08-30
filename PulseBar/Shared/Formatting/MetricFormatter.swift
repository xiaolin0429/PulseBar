import Foundation

public enum MetricFormatter {
    public struct TwoLineColumn: Equatable, Sendable {
        public let top: String
        public let bottom: String

        public init(top: String, bottom: String) {
            self.top = top
            self.bottom = bottom
        }
    }

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

    public static func twoLineLabel(
        columns: [TwoLineColumn],
        spacing: Int = 1
    ) -> String {
        guard !columns.isEmpty else { return "" }

        let paddedColumns = columns.map { column in
            let width = max(column.top.count, column.bottom.count)
            return (
                top: centered(column.top, width: width),
                bottom: centered(column.bottom, width: width)
            )
        }
        let separator = String(repeating: " ", count: max(spacing, 0))

        return paddedColumns.map(\.top).joined(separator: separator)
            + "\n"
            + paddedColumns.map(\.bottom).joined(separator: separator)
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

    private static func centered(_ value: String, width: Int) -> String {
        let padding = max(width - value.count, 0)
        let leading = padding / 2
        let trailing = padding - leading
        return String(repeating: " ", count: leading)
            + value
            + String(repeating: " ", count: trailing)
    }
}
