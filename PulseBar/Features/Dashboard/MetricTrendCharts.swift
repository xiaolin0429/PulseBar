import SwiftUI

private let maximumRenderedTrendPoints = 60

struct PercentTrendChart: View {
    let points: [HistoryPoint]
    let color: Color
    let accessibilityName: LocalizedStringKey
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 5) {
            TrendAxisLabels(top: "100%", middle: "50%", bottom: "0%")
            LightweightTrendPlot(
                series: [
                    TrendSeries(
                        id: "percent",
                        color: color,
                        samples: TrendSamples.make(
                            TrendPointReducer.reduce(
                                points,
                                maximumCount: maximumRenderedTrendPoints
                            ),
                            upperBound: 1
                        )
                    )
                ],
                filledSeriesID: "percent"
            )
        }
        .frame(height: 82)
        .accessibilityElement(children: .ignore)
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
        let reducedPrimary = TrendPointReducer.reduce(
            primary,
            maximumCount: maximumRenderedTrendPoints
        )
        let reducedSecondary = TrendPointReducer.reduce(
            secondary,
            maximumCount: maximumRenderedTrendPoints
        )
        let maximum = max(
            reducedPrimary.map(\.value).max() ?? 0,
            reducedSecondary.map(\.value).max() ?? 0
        )
        let upperBound = max(1, maximum)
        let sequenceRange = TrendSamples.sequenceRange(
            primary: reducedPrimary,
            secondary: reducedSecondary
        )

        VStack(spacing: 4) {
            HStack(spacing: 5) {
                TrendAxisLabels(
                    top: shortRate(maximum),
                    middle: shortRate(maximum / 2),
                    bottom: "0"
                )
                LightweightTrendPlot(
                    series: [
                        TrendSeries(
                            id: "primary",
                            color: primaryColor,
                            samples: TrendSamples.make(
                                reducedPrimary,
                                upperBound: upperBound,
                                sequenceRange: sequenceRange
                            )
                        ),
                        TrendSeries(
                            id: "secondary",
                            color: secondaryColor,
                            samples: TrendSamples.make(
                                reducedSecondary,
                                upperBound: upperBound,
                                sequenceRange: sequenceRange
                            )
                        )
                    ]
                )
            }
            .frame(height: 78)

            HStack(spacing: 10) {
                TrendLegendItem(name: primaryName, color: primaryColor)
                TrendLegendItem(name: secondaryName, color: secondaryColor)
                Spacer(minLength: 0)
            }
            .font(.system(size: 9))
        }
        .frame(height: 100)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("吞吐速率趋势")
        .accessibilityValue(accessibilityValue)
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
        if value >= 1_000_000_000 {
            return "\((value / 1_000_000_000).formatted(.number.precision(.fractionLength(1))))G"
        }
        if value >= 1_000_000 {
            return "\((value / 1_000_000).formatted(.number.precision(.fractionLength(1))))M"
        }
        if value >= 1_000 {
            return "\((value / 1_000).formatted(.number.precision(.fractionLength(0))))K"
        }
        return value.formatted(.number.precision(.fractionLength(0)))
    }
}
