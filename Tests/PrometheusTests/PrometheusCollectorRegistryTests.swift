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

import XCTest
import Prometheus

final class PrometheusCollectorRegistryTests: XCTestCase {
    func testAskingForTheSameCounterReturnsTheSameCounter() {
        let client = PrometheusCollectorRegistry()
        let counter1 = client.makeCounter(name: "foo")
        let counter2 = client.makeCounter(name: "foo")

        XCTAssert(counter1 === counter2)
        counter1.increment()
        counter2.increment(by: Int64(2))

        var buffer = [UInt8]()
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo counter
            foo 3

            """
        )
    }

    func testAskingForTheSameCounterWithLabelsReturnsTheSameCounter() {
        let client = PrometheusCollectorRegistry()
        let counter1 = client.makeCounter(name: "foo", labels: [("bar", "baz")])
        let counter2 = client.makeCounter(name: "foo", labels: [("bar", "baz")])

        XCTAssert(counter1 === counter2)
        counter1.increment()
        counter2.increment(by: Int64(2))

        var buffer = [UInt8]()
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo counter
            foo{bar="baz"} 3

            """
        )
    }

    func testAskingForTheSameCounterWithDifferentLabelsReturnsTheDifferentCounters() {
        let client = PrometheusCollectorRegistry()
        let counter1 = client.makeCounter(name: "foo", labels: [("bar", "baz")])
        let counter2 = client.makeCounter(name: "foo", labels: [("bar", "xyz")])

        XCTAssert(counter1 !== counter2)
        counter1.increment()
        counter2.increment(by: Int64(2))

        var buffer = [UInt8]()
        client.emit(into: &buffer)
        let output = String(decoding: buffer, as: Unicode.UTF8.self)
        XCTAssert(output.hasPrefix("# TYPE foo counter\n"))
        XCTAssert(output.contains(#"foo{bar="baz"} 1\#n"#))
        XCTAssert(output.contains(#"foo{bar="xyz"} 2\#n"#))
    }


    func testAskingForTheSameGaugeReturnsTheSameGauge() {
        let client = PrometheusCollectorRegistry()
        let gauge1 = client.makeGauge(name: "foo")
        let gauge2 = client.makeGauge(name: "foo")

        XCTAssert(gauge1 === gauge2)

        gauge1.increment(by: 1)
        gauge2.increment(by: 2)

        var buffer = [UInt8]()
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo gauge
            foo 3.0

            """
        )
    }

    func testAskingForTheSameGaugeWithLabelsReturnsTheSameGauge() {
        let client = PrometheusCollectorRegistry()
        let gauge1 = client.makeGauge(name: "foo", labels: [("bar", "baz")])
        let gauge2 = client.makeGauge(name: "foo", labels: [("bar", "baz")])

        XCTAssert(gauge1 === gauge2)

        gauge1.increment(by: 1)
        gauge2.increment(by: 2)

        var buffer = [UInt8]()
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo gauge
            foo{bar="baz"} 3.0

            """
        )
    }


    func testAskingForTheSameHistogramReturnsTheSameTimeHistogram() {
        let client = PrometheusCollectorRegistry()
        let histogram1 = client.makeHistogram(name: "foo", buckets: [1, 2, 3])
        let histogram2 = client.makeHistogram(name: "foo", buckets: [1, 2, 3])

        XCTAssert(histogram1 === histogram2)
        histogram1.record(2.5)
        histogram2.record(1.5)

        var buffer = [UInt8]()
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{le="1.0"} 0
            foo_bucket{le="2.0"} 1
            foo_bucket{le="3.0"} 2
            foo_bucket{le="+Inf"} 2
            foo_sum 4.0
            foo_count 2

            """
        )
    }

    func testAskingForTheSameHistogramWithLabelsReturnsTheSameTimeHistogram() {
        let client = PrometheusCollectorRegistry()
        let histogram1 = client.makeHistogram(name: "foo", labels: [("bar", "baz")], buckets: [1, 2, 3])
        let histogram2 = client.makeHistogram(name: "foo", labels: [("bar", "baz")], buckets: [1, 2, 3])

        XCTAssert(histogram1 === histogram2)
        histogram1.record(2.5)
        histogram2.record(1.5)

        var buffer = [UInt8]()
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{bar="baz",le="1.0"} 0
            foo_bucket{bar="baz",le="2.0"} 1
            foo_bucket{bar="baz",le="3.0"} 2
            foo_bucket{bar="baz",le="+Inf"} 2
            foo_sum{bar="baz"} 4.0
            foo_count{bar="baz"} 2

            """
        )
    }
}
