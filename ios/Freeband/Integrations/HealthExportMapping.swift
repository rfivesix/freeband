import Foundation

/// Converts only explicitly eligible real-band inputs. Callers must establish provenance and
/// timestamp integrity before setting `eligible`; derived UI data alone does not establish either.
enum HealthExportMapping {
    static func minutes(_ series: MinuteSeries, namespace: UUID, eligible: Bool) -> [HealthExportSample] {
        guard eligible else { return [] }
        let start = series.day.start(offsetMinutes: series.tzOffsetMinutes)
        var samples: [HealthExportSample] = []
        for index in 0 ..< MinuteSeries.slots {
            let time = start.addingTimeInterval(TimeInterval(index * 60))
            if let steps = series.steps[index], steps > 0 {
                samples.append(.init(namespace: namespace, kind: .steps, start: time,
                                     end: time.addingTimeInterval(60), value: steps))
            }
            if let heartRate = ValidRange.hr(series.heartRate[index]) {
                samples.append(.init(namespace: namespace, kind: .heartRate, start: time,
                                     end: time, value: heartRate))
            }
            if let oxygen = ValidRange.spo2(series.spo2[index]) {
                samples.append(.init(namespace: namespace, kind: .oxygen, start: time, end: time, value: oxygen))
            }
        }
        return samples
    }

    static func sleep(_ segments: [StageSegment], bed: Date, wake: Date,
                      namespace: UUID, eligible: Bool) -> [HealthExportSample] {
        guard eligible, bed < wake else { return [] }
        var result: [HealthExportSample] = []
        for segment in segments {
            guard segment.minutes > 0, segment.start >= bed, segment.end <= wake,
                  segment.stage != .unknown, segment.stage != .notSleep else { continue }
            result.append(.init(namespace: namespace, kind: .sleep, start: segment.start,
                                end: segment.end, value: Int(segment.stage.rawValue)))
        }
        return result
    }
    /// SDNN in milliseconds, calculated from RR intervals rather than the nightly RMSSD.
    /// Require an independently placeable packet time; never invent a Health sample time.
    static func variability(_ segments: [RRSegment], bed: Date, wake: Date,
                            namespace: UUID, eligible: Bool) -> [HealthExportSample] {
        guard eligible, bed < wake else { return [] }
        var samples: [HealthExportSample] = []
        for segment in segments {
            let candidates = [1.0, 1000.0, 1_000_000_000.0].map {
                Date(timeIntervalSince1970: Double(segment.tsRaw) / $0)
            }.filter { $0 >= bed && $0 < wake }
            guard candidates.count == 1, let start = candidates.first else { continue }
            var elapsed = 0.0, windowStart = 0.0
            var beats: [Int] = []
            func close() {
                let duration = elapsed - windowStart
                defer { windowStart = elapsed; beats = [] }
                let begin = start.addingTimeInterval(windowStart), end = start.addingTimeInterval(elapsed)
                guard duration >= HRV.minWindowSeconds, end <= wake, beats.count >= 2 else { return }
                var valid = Set<Int>()
                var pairs = 0
                for i in 1 ..< beats.count {
                    let a = beats[i - 1], b = beats[i]
                    guard HRV.rrRange.contains(a), HRV.rrRange.contains(b),
                          Double(abs(b - a)) <= HRV.maxJump * Double(a) else { continue }
                    pairs += 1; valid.insert(i - 1); valid.insert(i)
                }
                guard pairs >= HRV.minDifferences,
                      Double(pairs) >= HRV.minValidFraction * Double(beats.count - 1) else { return }
                let values = valid.sorted().map { Double(beats[$0]) }
                let mean = values.reduce(0, +) / Double(values.count)
                let variance = values.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(values.count)
                let sdnn = variance.squareRoot()
                guard sdnn.isFinite else { return }
                samples.append(.init(namespace: namespace, kind: .heartRateVariability,
                                     start: begin, end: end, value: Int(sdnn.rounded())))
            }
            for rr in segment.intervalsMs {
                beats.append(rr)
                elapsed += Double(min(max(rr, 0), HRV.rrRange.upperBound)) / 1000
                if elapsed - windowStart >= HRV.windowSeconds { close() }
            }
            close()
        }
        // Overlapping packets do not represent independent time windows.
        let sorted = samples.sorted { $0.start < $1.start }
        var nonoverlapping: [HealthExportSample] = []
        for sample in sorted {
            if let last = nonoverlapping.last, sample.start < last.end { continue }
            nonoverlapping.append(sample)
        }
        return nonoverlapping
    }

}
