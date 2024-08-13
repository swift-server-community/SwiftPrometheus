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

public func runGaugeBench(_ iterations: Range<Int>) {
    let gauge = registry.makeGauge(name: "gauge_1", labels: makeLabels(2))
    for _ in iterations {
        blackHole(gauge.increment())
    }
}

public func setupGaugeBench() -> () -> Void {
    let gauge = registry.makeGauge(name: "gauge_1", labels: makeLabels(2))
    return {
        blackHole(gauge.increment())
    }
}
