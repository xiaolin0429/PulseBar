import SwiftUI

struct CPUCardView: View {
    let metric: MetricValue<CPUSnapshot>
    let history: [HistoryPoint]
    @State private var coresExpanded = false

    var body: some View {
        MetricCardView(title: "CPU", systemImage: "cpu", tint: .blue) {
            MetricStateView(value: metric) { snapshot in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(percent(snapshot.totalUsageRatio))
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("用户 \(percent(snapshot.userUsageRatio))")
                            Text("系统 \(percent(snapshot.systemUsageRatio))")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }

                    PercentTrendChart(points: history, color: .blue, accessibilityName: "CPU 使用率趋势")

                    DisclosureGroup(isExpanded: $coresExpanded) {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 74), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(Array(snapshot.perCoreUsageRatios.enumerated()), id: \.offset) { index, value in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("\(index + 1)")
                                        Spacer()
                                        Text(percent(value))
                                            .monospacedDigit()
                                    }
                                    .font(.caption2)
                                    ProgressView(value: value)
                                        .tint(.blue)
                                }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("\(snapshot.perCoreUsageRatios.count) 个逻辑核心")
                            .font(.caption)
                    }

                    if let one = snapshot.loadAverage1m,
                       let five = snapshot.loadAverage5m,
                       let fifteen = snapshot.loadAverage15m {
                        Text(
                            "负载平均值  \(number(one))  ·  \(number(five))  ·  \(number(fifteen))"
                        )
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                    }
                }
            }
        }
    }

    private func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }
}
