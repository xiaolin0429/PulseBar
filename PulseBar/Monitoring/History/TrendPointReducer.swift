import Foundation

public enum TrendPointReducer {
    public static func reduce(
        _ points: [HistoryPoint],
        maximumCount: Int = 60
    ) -> [HistoryPoint] {
        guard maximumCount > 0, !points.isEmpty else { return [] }
        guard points.count > maximumCount else { return points }
        guard maximumCount > 1 else { return [points[points.count - 1]] }
        guard maximumCount > 2 else { return [points[0], points[points.count - 1]] }

        let interior = points.dropFirst().dropLast()
        let interiorBudget = maximumCount - 2
        let bucketCount = max(1, (interiorBudget + 1) / 2)
        let bucketSize = max(1, Int(ceil(Double(interior.count) / Double(bucketCount))))

        var result: [HistoryPoint] = []
        result.reserveCapacity(maximumCount)
        result.append(points[0])

        var bucketStart = interior.startIndex
        while bucketStart < interior.endIndex, result.count < maximumCount - 1 {
            let bucketEnd = interior.index(
                bucketStart,
                offsetBy: bucketSize,
                limitedBy: interior.endIndex
            ) ?? interior.endIndex
            let bucket = interior[bucketStart..<bucketEnd]

            if let minimum = bucket.min(by: { $0.value < $1.value }),
               let maximum = bucket.max(by: { $0.value < $1.value }) {
                let extrema = minimum.sequence <= maximum.sequence
                    ? [minimum, maximum]
                    : [maximum, minimum]
                for point in extrema where result.count < maximumCount - 1 {
                    if result.last?.sequence != point.sequence {
                        result.append(point)
                    }
                }
            }
            bucketStart = bucketEnd
        }

        if result.last?.sequence != points[points.count - 1].sequence {
            result.append(points[points.count - 1])
        }
        return result
    }
}
