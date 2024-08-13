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

public func runCounterBench(_ iterations: Range<Int>) {
    let ctr = registry.makeCounter(name: "counter_1", labels: makeLabels(1))
    for _ in iterations {
        blackHole(ctr.increment())
    }
}

public func setupCounterBench() -> () -> Void {
    let ctr = registry.makeCounter(name: "counter_2", labels: makeLabels(2))
    return {
        blackHole(ctr.increment())
    }
}
