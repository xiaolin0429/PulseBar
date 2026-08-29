import Charts
import SwiftUI

struct PercentTrendChart: View {
    let points: [HistoryPoint]
    let color: Color
    let accessibilityName: LocalizedStringKey
    @Environment(\.locale) private var locale

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("时间", point.wallTime),
                y: .value("百分比", point.value * 100)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [color.opacity(0.22), color.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            LineMark(
                x: .value("时间", point.wallTime),
                y: .value("百分比", point.value * 100)
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine().foregroundStyle(.separator.opacity(0.35))
                AxisValueLabel {
                    if let number = value.as(Int.self) {
                        Text("\(number)%")
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 82)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(chartAccessibilityValue(points))
    }

    private func chartAccessibilityValue(_ points: [HistoryPoint]) -> String {
        guard let latest = points.last else {
            return String(localized: "暂无历史数据", locale: locale)
        }
        return String(
            localized: "最近值 \(Int((latest.value * 100).rounded()))%",
            locale: locale
        )
    }
}

struct ThroughputTrendChart: View {
    let primary: [HistoryPoint]
    let secondary: [HistoryPoint]
    let primaryName: String
    let secondaryName: String
    let primaryColor: Color
    let secondaryColor: Color
    @Environment(\.unitSystem) private var unitSystem
    @Environment(\.locale) private var locale

    var body: some View {
        Chart(series) { point in
            LineMark(
                x: .value("时间", point.wallTime),
                y: .value("速率", point.value)
            )
            .foregroundStyle(by: .value("方向", point.series))
            .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartForegroundStyleScale([
            primaryName: primaryColor,
            secondaryName: secondaryColor
        ])
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(.separator.opacity(0.35))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(shortRate(number))
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            }
        }
        .chartLegend(position: .bottom, alignment: .leading, spacing: 10)
        .frame(height: 100)
        .accessibilityLabel("吞吐速率趋势")
        .accessibilityValue(accessibilityValue)
    }

    private var series: [SeriesPoint] {
        primary.map {
            SeriesPoint(id: "primary-\($0.sequence)", wallTime: $0.wallTime, value: $0.value, series: primaryName)
        } + secondary.map {
            SeriesPoint(id: "secondary-\($0.sequence)", wallTime: $0.wallTime, value: $0.value, series: secondaryName)
        }
    }

    private var accessibilityValue: String {
        let first = primary.last.map {
            MetricFormatter.bytesPerSecond($0.value, unitSystem: unitSystem)
        } ?? String(localized: "暂无数据", locale: locale)
        let second = secondary.last.map {
            MetricFormatter.bytesPerSecond($0.value, unitSystem: unitSystem)
        } ?? String(localized: "暂无数据", locale: locale)
        return String(
            localized: "\(primaryName) \(first)，\(secondaryName) \(second)",
            locale: locale
        )
    }

    private func shortRate(_ value: Double) -> String {
        guard value > 0 else { return "0" }
        if value >= 1_000_000_000 { return "\((value / 1_000_000_000).formatted(.number.precision(.fractionLength(1))))G" }
        if value >= 1_000_000 { return "\((value / 1_000_000).formatted(.number.precision(.fractionLength(1))))M" }
        if value >= 1_000 { return "\((value / 1_000).formatted(.number.precision(.fractionLength(0))))K" }
        return value.formatted(.number.precision(.fractionLength(0)))
    }
}

private struct SeriesPoint: Identifiable {
    let id: String
    let wallTime: Date
    let value: Double
    let series: String
}
