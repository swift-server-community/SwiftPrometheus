//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftPrometheus open source project
//
// Copyright (c) 2018-2023 SwiftPrometheus project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftPrometheus project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CoreMetrics

/// A Histogram implementation, that is backed by buckets in Double
public final class Histogram: Sendable {
    let name: String
    let labels: [(String, String)]

    struct State: Sendable {
        var buckets: [(Double, Int)]
        var sum: Double
        var count: Int

        @inlinable
        init(buckets: [Double]) {
            self.sum = .zero
            self.count = 0
            self.buckets = buckets.map { ($0, 0) }
        }
    }

    let box: NIOLockedValueBox<State>
    let prerenderedLabels: [UInt8]?

    init(name: String, labels: [(String, String)], buckets: [Double]) {
        self.name = name
        self.labels = labels

        self.prerenderedLabels = Self.prerenderLabels(labels)

        self.box = .init(.init(buckets: buckets))
    }

    public func observe(_ value: Double) {
        self.box.withLockedValue { state in
            for i in state.buckets.startIndex..<state.buckets.endIndex {
                if state.buckets[i].0 >= value {
                    state.buckets[i].1 += 1
                }
            }
            state.sum += value
            state.count += 1
        }
    }

    public func observe(_ value: Duration) {
        let value = Double(value.components.seconds) + Double(value.components.attoseconds) / 1e18
        self.observe(value)
    }
}

extension Histogram: _SwiftMetricsSendableProtocol {}

extension Histogram: CoreMetrics.TimerHandler {
    public func recordNanoseconds(_ duration: Int64) {
        let value = Duration.nanoseconds(duration)
        self.observe(value)
    }
}

extension Histogram: CoreMetrics.RecorderHandler {
    public func record(_ value: Double) {
        self.observe(value)
    }
    
    public func record(_ value: Int64) {
        self.observe(Double(value))
    }
}

extension Histogram: PrometheusMetric {
    func emit(into buffer: inout [UInt8]) {
        let state = self.box.withLockedValue { $0 }

        for bucket in state.buckets {
            buffer.append(contentsOf: self.name.utf8)
            buffer.append(contentsOf: #"_bucket{"#.utf8)
            if let prerenderedLabels {
                buffer.append(contentsOf: prerenderedLabels)
                buffer.append(UInt8(ascii: #","#))
            }
            buffer.append(contentsOf: #"le=""#.utf8)
            buffer.append(contentsOf: "\(bucket.0)".utf8)
            buffer.append(UInt8(ascii: #"""#))
            buffer.append(contentsOf: #"} "#.utf8)
            buffer.append(contentsOf: "\(bucket.1)".utf8)
            buffer.append(contentsOf: #"\#n"#.utf8)
        }

        // +Inf
        buffer.append(contentsOf: self.name.utf8)
        buffer.append(contentsOf: #"_bucket{"#.utf8)
        if let prerenderedLabels {
            buffer.append(contentsOf: prerenderedLabels)
            buffer.append(UInt8(ascii: ","))
        }
        buffer.append(contentsOf: #"le="+Inf"} "#.utf8)
        buffer.append(contentsOf: "\(state.count)".utf8)
        buffer.append(contentsOf: #"\#n"#.utf8)

        // sum
        buffer.append(contentsOf: self.name.utf8)
        buffer.append(contentsOf: #"_sum"#.utf8)
        if let prerenderedLabels {
            buffer.append(UInt8(ascii: "{"))
            buffer.append(contentsOf: prerenderedLabels)
            buffer.append(contentsOf: #"} "#.utf8)
        } else {
            buffer.append(UInt8(ascii: " "))
        }
        buffer.append(contentsOf: "\(state.sum)".utf8)
        buffer.append(contentsOf: #"\#n"#.utf8)

        // count
        buffer.append(contentsOf: self.name.utf8)
        buffer.append(contentsOf: #"_count"#.utf8)
        if let prerenderedLabels {
            buffer.append(UInt8(ascii: "{"))
            buffer.append(contentsOf: prerenderedLabels)
            buffer.append(contentsOf: #"} "#.utf8)
        } else {
            buffer.append(UInt8(ascii: " "))
        }
        buffer.append(contentsOf: "\(state.count)".utf8)
        buffer.append(contentsOf: #"\#n"#.utf8)
    }
}
