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

public func setupRegistryExport(numberOfMetrics: Int) -> () -> Void {
    let registryExport = PrometheusCollectorRegistry()

    var counterArray = [Counter]()
    var gaugeArray = [Gauge]()
    var buffer = [UInt8]()

    let counterExportSize = 620_000
    counterArray.reserveCapacity(numberOfMetrics)
    gaugeArray.reserveCapacity(numberOfMetrics)
    buffer.reserveCapacity(counterExportSize)

    for i in 0..<(numberOfMetrics / 2) {
        let counter = registryExport.makeCounter(name: "http_requests_total", labels: makeLabels(i))
        counter.increment()
        counterArray.append(counter)

        let gauge = registryExport.makeGauge(name: "export_gauge_\(i)", labels: makeLabels(i))
        gauge.increment()
        gaugeArray.append(gauge)
    }
    return {
        blackHole(registryExport.emit(into: &buffer))
    }
}
