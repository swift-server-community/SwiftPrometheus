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

final class HistogramTests: XCTestCase {
    func testHistogramWithoutDimensions() {
        let client = PrometheusCollectorRegistry()
        let histogram = client.makeHistogram(name: "foo", labels: [], buckets: [
            0.1, 0.25, 0.5, 1,
        ])

        var buffer = [UInt8]()
        client.emit(into: &buffer)

        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{le="0.1"} 0
            foo_bucket{le="0.25"} 0
            foo_bucket{le="0.5"} 0
            foo_bucket{le="1.0"} 0
            foo_bucket{le="+Inf"} 0
            foo_sum 0.0
            foo_count 0

            """
        )

        // Record 400ms
        buffer.removeAll(keepingCapacity: true)
        histogram.recordNanoseconds(400_000_000) // 400ms
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{le="0.1"} 0
            foo_bucket{le="0.25"} 0
            foo_bucket{le="0.5"} 1
            foo_bucket{le="1.0"} 1
            foo_bucket{le="+Inf"} 1
            foo_sum 0.4
            foo_count 1

            """
        )

        // Record 600ms
        buffer.removeAll(keepingCapacity: true)
        histogram.recordNanoseconds(600_000_000) // 600ms
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{le="0.1"} 0
            foo_bucket{le="0.25"} 0
            foo_bucket{le="0.5"} 1
            foo_bucket{le="1.0"} 2
            foo_bucket{le="+Inf"} 2
            foo_sum 1.0
            foo_count 2

            """
        )

        // Record 1200ms
        buffer.removeAll(keepingCapacity: true)
        histogram.recordNanoseconds(1_200_000_000) // 1200ms
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{le="0.1"} 0
            foo_bucket{le="0.25"} 0
            foo_bucket{le="0.5"} 1
            foo_bucket{le="1.0"} 2
            foo_bucket{le="+Inf"} 3
            foo_sum 2.2
            foo_count 3

            """
        )

        // Record 90ms
        buffer.removeAll(keepingCapacity: true)
        histogram.recordNanoseconds(90_000_000) // 90ms
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{le="0.1"} 1
            foo_bucket{le="0.25"} 1
            foo_bucket{le="0.5"} 2
            foo_bucket{le="1.0"} 3
            foo_bucket{le="+Inf"} 4
            foo_sum 2.29
            foo_count 4

            """
        )
    }

    func testHistogramWithOneDimension() {
        let client = PrometheusCollectorRegistry()
        let histogram = client.makeHistogram(name: "foo", labels: [("bar", "baz")], buckets: [
            0.1, 0.25, 0.5, 1,
        ])

        var buffer = [UInt8]()
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{bar="baz",le="0.1"} 0
            foo_bucket{bar="baz",le="0.25"} 0
            foo_bucket{bar="baz",le="0.5"} 0
            foo_bucket{bar="baz",le="1.0"} 0
            foo_bucket{bar="baz",le="+Inf"} 0
            foo_sum{bar="baz"} 0.0
            foo_count{bar="baz"} 0

            """
        )

        // Record 400ms
        buffer.removeAll(keepingCapacity: true)
        histogram.recordNanoseconds(400_000_000) // 400ms
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{bar="baz",le="0.1"} 0
            foo_bucket{bar="baz",le="0.25"} 0
            foo_bucket{bar="baz",le="0.5"} 1
            foo_bucket{bar="baz",le="1.0"} 1
            foo_bucket{bar="baz",le="+Inf"} 1
            foo_sum{bar="baz"} 0.4
            foo_count{bar="baz"} 1

            """
        )

        // Record 600ms
        buffer.removeAll(keepingCapacity: true)
        histogram.recordNanoseconds(600_000_000) // 600ms
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{bar="baz",le="0.1"} 0
            foo_bucket{bar="baz",le="0.25"} 0
            foo_bucket{bar="baz",le="0.5"} 1
            foo_bucket{bar="baz",le="1.0"} 2
            foo_bucket{bar="baz",le="+Inf"} 2
            foo_sum{bar="baz"} 1.0
            foo_count{bar="baz"} 2

            """
        )

        // Record 1200ms
        buffer.removeAll(keepingCapacity: true)
        histogram.recordNanoseconds(1_200_000_000) // 1200ms
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{bar="baz",le="0.1"} 0
            foo_bucket{bar="baz",le="0.25"} 0
            foo_bucket{bar="baz",le="0.5"} 1
            foo_bucket{bar="baz",le="1.0"} 2
            foo_bucket{bar="baz",le="+Inf"} 3
            foo_sum{bar="baz"} 2.2
            foo_count{bar="baz"} 3

            """
        )

        // Record 90ms
        buffer.removeAll(keepingCapacity: true)
        histogram.recordNanoseconds(90_000_000) // 90ms
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{bar="baz",le="0.1"} 1
            foo_bucket{bar="baz",le="0.25"} 1
            foo_bucket{bar="baz",le="0.5"} 2
            foo_bucket{bar="baz",le="1.0"} 3
            foo_bucket{bar="baz",le="+Inf"} 4
            foo_sum{bar="baz"} 2.29
            foo_count{bar="baz"} 4

            """
        )
    }

    func testHistogramWithTwoDimension() {
        let client = PrometheusCollectorRegistry()
        let histogram = client.makeHistogram(name: "foo", labels: [("bar", "baz"), ("abc", "xyz")], buckets: [
            0.1, 0.25, 0.5, 1,
        ])

        var buffer = [UInt8]()
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{bar="baz",abc="xyz",le="0.1"} 0
            foo_bucket{bar="baz",abc="xyz",le="0.25"} 0
            foo_bucket{bar="baz",abc="xyz",le="0.5"} 0
            foo_bucket{bar="baz",abc="xyz",le="1.0"} 0
            foo_bucket{bar="baz",abc="xyz",le="+Inf"} 0
            foo_sum{bar="baz",abc="xyz"} 0.0
            foo_count{bar="baz",abc="xyz"} 0

            """
        )

        // Record 400ms
        buffer.removeAll(keepingCapacity: true)
        histogram.recordNanoseconds(400_000_000) // 400ms
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{bar="baz",abc="xyz",le="0.1"} 0
            foo_bucket{bar="baz",abc="xyz",le="0.25"} 0
            foo_bucket{bar="baz",abc="xyz",le="0.5"} 1
            foo_bucket{bar="baz",abc="xyz",le="1.0"} 1
            foo_bucket{bar="baz",abc="xyz",le="+Inf"} 1
            foo_sum{bar="baz",abc="xyz"} 0.4
            foo_count{bar="baz",abc="xyz"} 1

            """
        )

        // Record 600ms
        buffer.removeAll(keepingCapacity: true)
        histogram.recordNanoseconds(600_000_000) // 600ms
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{bar="baz",abc="xyz",le="0.1"} 0
            foo_bucket{bar="baz",abc="xyz",le="0.25"} 0
            foo_bucket{bar="baz",abc="xyz",le="0.5"} 1
            foo_bucket{bar="baz",abc="xyz",le="1.0"} 2
            foo_bucket{bar="baz",abc="xyz",le="+Inf"} 2
            foo_sum{bar="baz",abc="xyz"} 1.0
            foo_count{bar="baz",abc="xyz"} 2

            """
        )

        // Record 1200ms
        buffer.removeAll(keepingCapacity: true)
        histogram.recordNanoseconds(1_200_000_000) // 1200ms
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{bar="baz",abc="xyz",le="0.1"} 0
            foo_bucket{bar="baz",abc="xyz",le="0.25"} 0
            foo_bucket{bar="baz",abc="xyz",le="0.5"} 1
            foo_bucket{bar="baz",abc="xyz",le="1.0"} 2
            foo_bucket{bar="baz",abc="xyz",le="+Inf"} 3
            foo_sum{bar="baz",abc="xyz"} 2.2
            foo_count{bar="baz",abc="xyz"} 3

            """
        )

        // Record 90ms
        buffer.removeAll(keepingCapacity: true)
        histogram.recordNanoseconds(90_000_000) // 90ms
        client.emit(into: &buffer)
        XCTAssertEqual(String(decoding: buffer, as: Unicode.UTF8.self), """
            # TYPE foo histogram
            foo_bucket{bar="baz",abc="xyz",le="0.1"} 1
            foo_bucket{bar="baz",abc="xyz",le="0.25"} 1
            foo_bucket{bar="baz",abc="xyz",le="0.5"} 2
            foo_bucket{bar="baz",abc="xyz",le="1.0"} 3
            foo_bucket{bar="baz",abc="xyz",le="+Inf"} 4
            foo_sum{bar="baz",abc="xyz"} 2.29
            foo_count{bar="baz",abc="xyz"} 4

            """
        )
    }
}
