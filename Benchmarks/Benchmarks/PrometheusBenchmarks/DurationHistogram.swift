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

import Benchmark
import Prometheus

public func runDurationHistogramBench(_ iterations: Range<Int>) {
    let histogram = registry.makeDurationHistogram(
        name: "histogram_1",
        labels: makeLabels(3),
        buckets: [
            .milliseconds(100),
            .milliseconds(250),
            .milliseconds(500),
            .seconds(1),
        ]
    )
    for _ in iterations {
        blackHole(histogram.record(Duration.milliseconds(400)))
    }
}
