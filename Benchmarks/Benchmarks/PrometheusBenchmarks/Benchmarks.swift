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

let registry = PrometheusCollectorRegistry()

public func makeLabels(_ idx: Int) -> [(String, String)] {
    [
        ("job", "api_server_\(idx)"),
        ("handler", "/api/handler_\(idx)"),
        ("status_code", "200"),
        ("version", "\(idx).0.0"),
    ]
}

let benchmarks = {
    Benchmark.defaultConfiguration.maxDuration = .seconds(5)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.mallocCountTotal]

    Benchmark("Counter - setup and increment") { benchmark in
        runCounterBench(benchmark.scaledIterations)
    }

    Benchmark("Counter - increment only") { benchmark, run in
        for _ in benchmark.scaledIterations {
            run()
        }
    } setup: {
        setupCounterBench()
    }

    Benchmark("Gauge") { benchmark in
        runGaugeBench(benchmark.scaledIterations)
    }

    Benchmark("DurationHistogram") { benchmark in
        runDurationHistogramBench(benchmark.scaledIterations)
    }

    Benchmark("RegistryEmit - 5000 metrics",
              configuration: .init(scalingFactor: .one)) { benchmark, run in
        for _ in benchmark.scaledIterations {
            run()
        }
    } setup: {
        setupRegistryExport(numberOfMetrics: 5000)
    }
}
