import SwiftUI

struct MetricCardView<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            content
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.separator.opacity(0.6), lineWidth: 1)
        }
    }
}

struct MetricStateView<Value: Sendable & Equatable, Content: View>: View {
    let value: MetricValue<Value>
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        switch value {
        case let .available(snapshot):
            content(snapshot)
        case let .stale(snapshot, age):
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    "数据已延迟 \(Int(age.secondsValue.rounded())) 秒",
                    systemImage: "clock.badge.exclamationmark"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                content(snapshot)
                    .opacity(0.7)
            }
        case .warmingUp:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("正在建立采样基线…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        case let .unavailable(failure):
            VStack(alignment: .leading, spacing: 4) {
                Label("暂时无法读取", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                Text(LocalizedStringKey(failure.userMessageKey))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }
}

struct MetricValueRow: View {
    let label: LocalizedStringKey
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .font(.caption)
        .frame(maxWidth: .infinity)
    }
}
