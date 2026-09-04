import SwiftUI

struct LightweightTrendPlot: View {
    let series: [TrendSeries]
    let filledSeriesID: String?

    /// 保存已经归一化的绘图序列及可选填充序列 ID；这里只负责绘制，不采样或持有历史。
    init(series: [TrendSeries], filledSeriesID: String? = nil) {
        self.series = series
        self.filledSeriesID = filledSeriesID
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                TrendGridShape()
                    .stroke(.separator.opacity(0.35), lineWidth: 0.5)

                ForEach(series) { item in
                    if item.id == filledSeriesID {
                        TrendAreaShape(samples: item.samples)
                            .fill(item.color.opacity(0.12))
                    }
                    TrendLineShape(samples: item.samples)
                        .stroke(
                            item.color,
                            style: StrokeStyle(
                                lineWidth: 1.6,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }
            }
        }
    }
}

struct TrendAxisLabels: View {
    let top: String
    let middle: String
    let bottom: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(top)
            Spacer(minLength: 0)
            Text(middle)
            Spacer(minLength: 0)
            Text(bottom)
        }
        .font(.system(size: 9))
        .foregroundStyle(.tertiary)
        .monospacedDigit()
        .frame(width: 30, alignment: .trailing)
    }
}

struct TrendLegendItem: View {
    let name: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(name)
                .foregroundStyle(.secondary)
        }
    }
}

struct TrendSeries: Identifiable {
    let id: String
    let color: Color
    let samples: [TrendSample]
}

struct TrendSample {
    let x: Double
    let y: Double
}

enum TrendSamples {
    /// 将按序排列的历史点映射到归一化坐标，纵轴按正数 upperBound 缩放并夹到 0…1。
    /// 自定义 sequenceRange 必须包含所有点；横轴采用采样序号，而不是等比例时间间隔。
    static func make(
        _ points: [HistoryPoint],
        upperBound: Double,
        sequenceRange: ClosedRange<UInt64>? = nil
    ) -> [TrendSample] {
        guard let first = points.first, let last = points.last else { return [] }
        let range = sequenceRange ?? first.sequence...last.sequence
        let sequenceSpan = max(1, range.upperBound - range.lowerBound)
        return points.map { point in
            TrendSample(
                x: Double(point.sequence - range.lowerBound) / Double(sequenceSpan),
                y: min(1, max(0, point.value / upperBound))
            )
        }
    }

    /// 合并两条有序序列的首尾序号，使上下行或读写曲线共用横轴；均为空时返回 nil。
    static func sequenceRange(
        primary: [HistoryPoint],
        secondary: [HistoryPoint]
    ) -> ClosedRange<UInt64>? {
        let lowerBound = [primary.first?.sequence, secondary.first?.sequence]
            .compactMap { $0 }
            .min()
        let upperBound = [primary.last?.sequence, secondary.last?.sequence]
            .compactMap { $0 }
            .max()
        guard let lowerBound, let upperBound else { return nil }
        return lowerBound...upperBound
    }
}

private struct TrendLineShape: Shape {
    let samples: [TrendSample]

    /// 顺序连接样本点生成折线路径；空序列返回空路径。
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = samples.first else { return path }
        path.move(to: trendPosition(first, in: rect))
        for sample in samples.dropFirst() {
            path.addLine(to: trendPosition(sample, in: rect))
        }
        return path
    }
}

private struct TrendAreaShape: Shape {
    let samples: [TrendSample]

    /// 连接样本点并闭合到图表底边，生成折线下方的填充区域。
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = samples.first, let last = samples.last else { return path }
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: trendPosition(first, in: rect))
        for sample in samples.dropFirst() {
            path.addLine(to: trendPosition(sample, in: rect))
        }
        path.addLine(to: CGPoint(x: rect.minX + rect.width * last.x, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TrendGridShape: Shape {
    /// 绘制顶部、中线和底部三条水平参考线，无需构造额外网格视图。
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for ratio in [0.0, 0.5, 1.0] {
            let y = rect.minY + rect.height * ratio
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

/// 把归一化坐标映射到绘图矩形，并翻转纵轴，使较大数值显示在上方。
private func trendPosition(_ sample: TrendSample, in rect: CGRect) -> CGPoint {
    CGPoint(
        x: rect.minX + rect.width * sample.x,
        y: rect.maxY - rect.height * sample.y
    )
}
