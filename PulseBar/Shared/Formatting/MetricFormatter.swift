import Foundation

public enum MetricFormatter {
    public struct TwoLineColumn: Equatable, Sendable {
        public let top: String
        public let bottom: String

        /// 保存一个菜单栏列的上下两行文本；对齐由 twoLineLabel 统一处理。
        public init(top: String, bottom: String) {
            self.top = top
            self.bottom = bottom
        }
    }

    /// 格式化字节容量；默认采用二进制容量口径，并将输入夹到 Int64 可表示范围。
    public static func bytes(
        _ value: UInt64,
        unitSystem: UnitSystem = .mixedDefault
    ) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(clamping: value),
            countStyle: unitSystem == .decimal ? .decimal : .binary
        )
    }

    /// 格式化 B/s；默认采用十进制速率口径，负值或非有限值显示占位符。
    public static func bytesPerSecond(
        _ value: Double,
        unitSystem: UnitSystem = .mixedDefault
    ) -> String {
        guard value.isFinite, value >= 0 else { return "—" }
        let style: ByteCountFormatter.CountStyle = unitSystem == .binary ? .binary : .decimal
        return "\(ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: style))/s"
    }

    /// 使用 B/K/M 等短单位格式化菜单栏容量；默认以 1024 为进位基数。
    public static func compactBytes(
        _ value: UInt64,
        unitSystem: UnitSystem = .mixedDefault
    ) -> String {
        let base = unitSystem == .decimal ? 1_000.0 : 1_024.0
        return compactMagnitude(Double(value), base: base)
    }

    /// 使用紧凑短单位格式化菜单栏 B/s；默认以 1000 进位，无效值显示占位符。
    public static func compactBytesPerSecond(
        _ value: Double,
        unitSystem: UnitSystem = .mixedDefault
    ) -> String {
        guard value.isFinite, value >= 0 else { return "—" }
        let base = unitSystem == .binary ? 1_024.0 : 1_000.0
        return "\(compactMagnitude(value, base: base))/s"
    }

    /// 按每列较长一行的字符数补空格，拼成单一双行字符串，供等宽字体绘制。
    /// 列间距不小于零；整体作为一个标签可避免菜单栏只取到部分子视图。
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

    /// 按基数缩放并选用短后缀，处理舍入后进位；超大值封顶为 999P+ 以限制宽度。
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

    /// 大于等于 10 或接近整数时显示整数，其余保留一位小数；固定小数点格式。
    private static func compactNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if value >= 10 || abs(value - rounded) < 0.05 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    /// 左右补空格实现字符级居中；奇数个空格时右侧多一个。
    private static func centered(_ value: String, width: Int) -> String {
        let padding = max(width - value.count, 0)
        let leading = padding / 2
        let trailing = padding - leading
        return String(repeating: " ", count: leading)
            + value
            + String(repeating: " ", count: trailing)
    }
}
