# ``Prometheus``

A prometheus client library for Swift.

## Overview

``Prometheus`` supports creating ``Counter``s, ``Gauge``s and ``Histogram``s and exporting their
values in the Prometheus text format.

``Prometheus`` integrates with [Swift Metrics](doc:swift-metrics).

For general advice on how to use `Prometheus` make sure to also read the [Prometheus documentation][prometheus-docs].

## Installation

``Prometheus`` is available through Swift Package Manager. To include it in your project add the 
following dependency to your `Package.swift`:

```swift
  .package(url: "https://github.com/swift-server/swift-prometheus.git", from: "2.0.0")
```

Next, add the dependency to your target:

```swift
  .target(
    name: "MyTarget",
    dependencies: [
      // your other dependencies
      .product(name: "Prometheus", package: "swift-prometheus"),
    ]
  ),
```

## Usage

In your Swift file you must first `import Prometheus`:

```swift
import Prometheus
```

Next you need to create a ``PrometheusCollectorRegistry``, which you use to create ``Counter``s, 
``Gauge``s and ``Histogram``s.

```swift
let registry = PrometheusCollectorRegistry()

let myCounter = registry.makeCounter(name: "my_counter")
myCounter.increment()

let myGauge = registry.makeGauge(name: "my_gauge")
myGauge.increment()
myGauge.decrement()
```

Lastly, you can use your ``PrometheusCollectorRegistry`` to generate a Prometheus export in the 
text representation:

```swift
var buffer = [UInt8]()
buffer.reserveCapacity(1024) // potentially smart moves to reduce the number of reallocations
registry.emit(into: &buffer)

print(String(decoding: buffer, as: Unicode.UTF8.self))
```

## Topics

### Getting started

- <doc:swift-metrics>
- <doc:labels>
- ``PrometheusCollectorRegistry``
- ``PrometheusMetricsFactory``


### Metrics

- ``Counter``
- ``Gauge``
- ``Histogram``
- ``DurationHistogram``
- ``ValueHistogram``

[prometheus-docs]: https://prometheus.io/docs/introduction/overview/
