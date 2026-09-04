import Foundation

public extension Duration {
    /// 将秒与阿秒合并为小数秒，用于速率分母及单调时钟耗时计算。
    var secondsValue: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
