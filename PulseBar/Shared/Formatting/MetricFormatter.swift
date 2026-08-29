import Foundation

public enum MetricFormatter {
    public static func bytes(_ value: UInt64, style: ByteCountFormatter.CountStyle = .binary) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: style)
    }

    public static func bytesPerSecond(
        _ value: Double,
        style: ByteCountFormatter.CountStyle = .decimal
    ) -> String {
        guard value.isFinite, value >= 0 else { return "—" }
        return "\(ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: style))/s"
    }
}
