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

/// A promtheus collector registry to create and store collectors.
///
/// It creates and stores collectors. Further you can use the ``PrometheusCollectorRegistry/emit(into:)``
/// method to export the metrics form registered collectors into a Prometheus compatible format.
///
/// To use a ``PrometheusCollectorRegistry`` with `swift-metrics` use the ``PrometheusMetricsFactory``.
public final class PrometheusCollectorRegistry: Sendable {
    private struct LabelsKey: Hashable, Sendable {
        var labels: [(String, String)]

        init(_ labels: [(String, String)]) {
            self.labels = labels
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            guard lhs.labels.count == rhs.labels.count else { return false }

            for (lhs, rhs) in zip(lhs.labels, rhs.labels) {
                guard lhs.0 == rhs.0 && lhs.1 == rhs.1 else {
                    return false
                }
            }
            return true
        }

        func hash(into hasher: inout Hasher) {
            for (key, value) in self.labels {
                key.hash(into: &hasher)
                value.hash(into: &hasher)
            }
        }
    }

    private enum Metric {
        case counter(Counter)
        case counterWithLabels([String], [LabelsKey: Counter])
        case gauge(Gauge)
        case gaugeWithLabels([String], [LabelsKey: Gauge])
        case histogram(Histogram)
        case histogramWithLabels([String], [LabelsKey: Histogram], [Double])
    }

    private let box = NIOLockedValueBox([String: Metric]())

    /// Create a new collector registry
    public init() {}

    // MARK: Creating Metrics

    /// Creates a new ``Counter`` collector or returns the already existing one with the same name.
    ///
    /// When the ``PrometheusCollectorRegistry/emit(into:)`` is called, metrics from the
    /// created ``Counter`` will be part of the export.
    ///
    /// - Parameter name: A name to identify ``Counter``'s value.
    /// - Returns: A ``Counter`` that is registered with this ``PrometheusCollectorRegistry``
    public func makeCounter(name: String) -> Counter {
        self.box.withLockedValue { store -> Counter in
            if let value = store[name] {
                guard case .counter(let counter) = value else {
                    fatalError("""
                        Could not make Counter with name: \(name), since another metric type
                        already exists for the same name.
                        """
                    )
                }

                return counter
            } else {
                let counter = Counter(name: name, labels: [])
                store[name] = .counter(counter)
                return counter
            }
        }
    }

    /// Creates a new ``Counter`` collector or returns the already existing one with the same name.
    ///
    /// When the ``PrometheusCollectorRegistry/emit(into:)`` is called, metrics from the
    /// created ``Counter`` will be part of the export.
    ///
    /// - Parameter name: A name to identify ``Counter``'s value.
    /// - Parameter labels: Labels are sets of key-value pairs that allow us to characterize and organize
    ///                     what’s actually being measured in a Prometheus metric.
    /// - Returns: A ``Counter`` that is registered with this ``PrometheusCollectorRegistry``
    public func makeCounter(name: String, labels: [(String, String)]) -> Counter {
        guard !labels.isEmpty else {
            return self.makeCounter(name: name)
        }

        return self.box.withLockedValue { store -> Counter in
            if let value = store[name] {
                guard case .counterWithLabels(let labelNames, var dimensionLookup) = value else {
                    fatalError("""
                        Could not make Counter with name: \(name) and labels: \(labels), since another
                        metric type already exists for the same name.
                        """
                    )
                }

                let key = LabelsKey(labels)
                if let counter = dimensionLookup[key] {
                    return counter
                }

                // check if all labels match the already existing ones.
                if labelNames != labels.allLabelNames {
                    fatalError("""
                        Could not make Counter with name: \(name) and labels: \(labels), since the
                        label names don't match the label names of previously registered Counters with
                        the same name.
                        """
                    )
                }

                let counter = Counter(name: name, labels: labels)
                dimensionLookup[key] = counter
                store[name] = .counterWithLabels(labelNames, dimensionLookup)
                return counter
            } else {
                let labelNames = labels.allLabelNames
                let counter = Counter(name: name, labels: labels)

                store[name] = .counterWithLabels(labelNames, [LabelsKey(labels): counter])
                return counter
            }
        }
    }

    /// Creates a new ``Gauge`` collector or returns the already existing one with the same name.
    ///
    /// When the ``PrometheusCollectorRegistry/emit(into:)`` is called, metrics from the
    /// created ``Gauge`` will be part of the export.
    ///
    /// - Parameter name: A name to identify ``Gauge``'s value.
    /// - Returns: A ``Gauge`` that is registered with this ``PrometheusCollectorRegistry``
    public func makeGauge(name: String) -> Gauge {
        self.box.withLockedValue { store -> Gauge in
            if let value = store[name] {
                guard case .gauge(let gauge) = value else {
                    fatalError("""
                        Could not make Gauge with name: \(name), since another metric type already
                        exists for the same name.
                        """
                    )
                }

                return gauge
            } else {
                let gauge = Gauge(name: name, labels: [])
                store[name] = .gauge(gauge)
                return gauge
            }
        }
    }

    /// Creates a new ``Gauge`` collector or returns the already existing one with the same name.
    ///
    /// When the ``PrometheusCollectorRegistry/emit(into:)`` is called, metrics from the
    /// created ``Gauge`` will be part of the export.
    ///
    /// - Parameter name: A name to identify ``Gauge``'s value.
    /// - Parameter labels: Labels are sets of key-value pairs that allow us to characterize and organize
    ///                     what’s actually being measured in a Prometheus metric.
    /// - Returns: A ``Gauge`` that is registered with this ``PrometheusCollectorRegistry``
    public func makeGauge(name: String, labels: [(String, String)]) -> Gauge {
        guard !labels.isEmpty else {
            return self.makeGauge(name: name)
        }

        return self.box.withLockedValue { store -> Gauge in
            if let value = store[name] {
                guard case .gaugeWithLabels(let labelNames, var dimensionLookup) = value else {
                    fatalError("""
                        Could not make Gauge with name: \(name) and labels: \(labels), since another
                        metric type already exists for the same name.
                        """
                    )
                }

                let key = LabelsKey(labels)
                if let gauge = dimensionLookup[key] {
                    return gauge
                }

                // check if all labels match the already existing ones.
                if labelNames != labels.allLabelNames {
                    fatalError("""
                        Could not make Gauge with name: \(name) and labels: \(labels), since the
                        label names don't match the label names of previously registered Gauges with
                        the same name.
                        """
                    )
                }

                let gauge = Gauge(name: name, labels: labels)
                dimensionLookup[key] = gauge
                store[name] = .gaugeWithLabels(labelNames, dimensionLookup)
                return gauge
            } else {
                let labelNames = labels.allLabelNames
                let gauge = Gauge(name: name, labels: labels)

                store[name] = .gaugeWithLabels(labelNames, [LabelsKey(labels): gauge])
                return gauge
            }
        }
    }

    /// Creates a new ``Histogram`` collector or returns the already existing one with the same name.
    ///
    /// When the ``PrometheusCollectorRegistry/emit(into:)`` is called, metrics from the
    /// created ``Histogram`` will be part of the export.
    ///
    /// - Parameter name: A name to identify ``Histogram``'s value.
    /// - Parameter buckets: Define the buckets that shall be used within the ``Histogram``
    /// - Returns: A ``Histogram`` that is registered with this ``PrometheusCollectorRegistry``
    public func makeHistogram(name: String, buckets: [Double]) -> Histogram {
        self.box.withLockedValue { store -> Histogram in
            if let value = store[name] {
                guard case .histogram(let histogram) = value else {
                    fatalError()
                }

                return histogram
            } else {
                let gauge = Histogram(name: name, labels: [], buckets: buckets)
                store[name] = .histogram(gauge)
                return gauge
            }
        }
    }

    /// Creates a new ``Histogram`` collector or returns the already existing one with the same name.
    ///
    /// When the ``PrometheusCollectorRegistry/emit(into:)`` is called, metrics from the
    /// created ``Histogram`` will be part of the export.
    ///
    /// - Parameter name: A name to identify ``Histogram``'s value.
    /// - Parameter labels: Labels are sets of key-value pairs that allow us to characterize and organize
    ///                     what’s actually being measured in a Prometheus metric.
    /// - Parameter buckets: Define the buckets that shall be used within the ``Histogram``
    /// - Returns: A ``Histogram`` that is registered with this ``PrometheusCollectorRegistry``
    public func makeHistogram(name: String, labels: [(String, String)], buckets: [Double]) -> Histogram {
        guard !labels.isEmpty else {
            return self.makeHistogram(name: name, buckets: buckets)
        }

        return self.box.withLockedValue { store -> Histogram in
            if let value = store[name] {
                guard case .histogramWithLabels(let labelNames, var dimensionLookup, let storedBuckets) = value else {
                    fatalError()
                }

                let key = LabelsKey(labels)
                if let histogram = dimensionLookup[key] {
                    return histogram
                }

                // check if all labels match the already existing ones.
                precondition(labelNames == labels.allLabelNames)
                precondition(storedBuckets == buckets)

                let histogram = Histogram(name: name, labels: labels, buckets: storedBuckets)
                dimensionLookup[key] = histogram
                store[name] = .histogramWithLabels(labelNames, dimensionLookup, storedBuckets)
                return histogram
            } else {
                let labelNames = labels.allLabelNames
                let histogram = Histogram(name: name, labels: labels, buckets: buckets)

                store[name] = .histogramWithLabels(labelNames, [LabelsKey(labels): histogram], buckets)
                return histogram
            }
        }
    }

    // MARK: Destroying Metrics
    
    /// Unregisters a ``Counter`` from the ``PrometheusCollectorRegistry``. This means that the provided ``Counter``
    /// will not be included in future ``emit(into:)`` calls.
    ///
    /// - Note: If the provided ``Counter`` is unknown to the registry this function call will be ignored
    /// - Parameter counter: The ``Counter`` that shall be removed from the registry
    public func unregisterCounter(_ counter: Counter) {
        self.box.withLockedValue { store in
            switch store[counter.name] {
            case .counter(let storedCounter):
                guard storedCounter === counter else { return }
                store.removeValue(forKey: counter.name)
            case .counterWithLabels(let labelNames, var dimensions):
                let labelsKey = LabelsKey(counter.labels)
                guard dimensions[labelsKey] === counter else { return }
                dimensions.removeValue(forKey: labelsKey)
                store[counter.name] = .counterWithLabels(labelNames, dimensions)
            default:
                return
            }
        }
    }

    /// Unregisters a ``Gauge`` from the ``PrometheusCollectorRegistry``. This means that the provided ``Gauge``
    /// will not be included in future ``emit(into:)`` calls.
    ///
    /// - Note: If the provided ``Gauge`` is unknown to the registry this function call will be ignored
    /// - Parameter gauge: The ``Gauge`` that shall be removed from the registry
    public func unregisterGauge(_ gauge: Gauge) {
        self.box.withLockedValue { store in
            switch store[gauge.name] {
            case .gauge(let storedGauge):
                guard storedGauge === gauge else { return }
                store.removeValue(forKey: gauge.name)
            case .gaugeWithLabels(let labelNames, var dimensions):
                let dimensionsKey = LabelsKey(gauge.labels)
                guard dimensions[dimensionsKey] === gauge else { return }
                dimensions.removeValue(forKey: dimensionsKey)
                store[gauge.name] = .gaugeWithLabels(labelNames, dimensions)
            default:
                return
            }
        }
    }

    /// Unregisters a ``Histogram`` from the ``PrometheusCollectorRegistry``. This means that this ``ValueHistogram``
    /// will not be included in future ``emit(into:)`` calls.
    ///
    /// - Note: If the provided ``ValueHistogram`` is unknown to the registry this function call will be ignored
    /// - Parameter histogram: The ``ValueHistogram`` that shall be removed from the registry
    public func unregisterHistogram(_ histogram: Histogram) {
        self.box.withLockedValue { store in
            switch store[histogram.name] {
            case .histogram(let storedHistogram):
                guard storedHistogram === histogram else { return }
                store.removeValue(forKey: histogram.name)
            case .histogramWithLabels(let labelNames, var dimensions, let buckets):
                let dimensionsKey = LabelsKey(histogram.labels)
                guard dimensions[dimensionsKey] === histogram else { return }
                dimensions.removeValue(forKey: dimensionsKey)
                store[histogram.name] = .histogramWithLabels(labelNames, dimensions, buckets)
            default:
                return
            }
        }
    }

    // MARK: Emitting

    public func emit(into buffer: inout [UInt8]) {
        let metrics = self.box.withLockedValue { $0 }

        for (label, metric) in metrics {
            switch metric {
            case .counter(let counter):
                buffer.addTypeLine(label: label, type: "counter")
                counter.emit(into: &buffer)
                
            case .counterWithLabels(_, let counters):
                buffer.addTypeLine(label: label, type: "counter")
                for counter in counters.values {
                    counter.emit(into: &buffer)
                }
                
            case .gauge(let gauge):
                buffer.addTypeLine(label: label, type: "gauge")
                gauge.emit(into: &buffer)
                
            case .gaugeWithLabels(_, let gauges):
                buffer.addTypeLine(label: label, type: "gauge")
                for gauge in gauges.values {
                    gauge.emit(into: &buffer)
                }
                
            case .histogram(let histogram):
                buffer.addTypeLine(label: label, type: "histogram")
                histogram.emit(into: &buffer)
                
            case .histogramWithLabels(_, let histograms, _):
                buffer.addTypeLine(label: label, type: "histogram")
                for histogram in histograms.values {
                    histogram.emit(into: &buffer)
                }
            }
        }
    }
}

extension Array<(String, String)> {
    fileprivate var allLabelNames: [String] {
        var result = [String]()
        result.reserveCapacity(self.count)
        for (name, _) in self {
            precondition(!result.contains(name))
            result.append(name)
        }
        result = result.sorted()
        return result
    }
}

extension Array<UInt8> {
    fileprivate mutating func addTypeLine(label: String, type: String) {
        self.append(contentsOf: #"# TYPE "#.utf8)
        self.append(contentsOf: label.utf8)
        self.append(contentsOf: #" "#.utf8)
        self.append(contentsOf: type.utf8)
        self.append(contentsOf: #"\#n"#.utf8)
    }
}

protocol PrometheusMetric {
    func emit(into buffer: inout [UInt8])
}

extension PrometheusMetric {
    static func prerenderLabels(_ labels: [(String, String)]) -> [UInt8]? {
        guard !labels.isEmpty else {
            return nil
        }

        var prerendered = [UInt8]()
        for (i, (key, value)) in labels.enumerated() {
            prerendered.append(contentsOf: key.utf8)
            prerendered.append(contentsOf: #"=""#.utf8)
            prerendered.append(contentsOf: value.utf8)
            prerendered.append(UInt8(ascii: #"""#))
            if i < labels.index(before: labels.endIndex) {
                prerendered.append(UInt8(ascii: #","#))
            }
        }
        return prerendered
    }
}
