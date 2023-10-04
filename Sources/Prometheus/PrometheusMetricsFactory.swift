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

/// A wrapper around ``PrometheusCollectorRegistry`` to implement the swift-metrics `MetricsFactory` protocol
public struct PrometheusMetricsFactory: Sendable {
    private static let _defaultRegistry = PrometheusCollectorRegistry()

    /// The default ``PrometheusCollectorRegistry``, which is used inside the ``PrometheusMetricsFactory``
    /// if no other is provided in ``init(client:)`` or set via ``PrometheusMetricsFactory/client``
    public static var defaultRegistry: PrometheusCollectorRegistry {
        self._defaultRegistry
    }

    /// The underlying ``PrometheusCollectorRegistry`` that is used to generate the swift-metrics handlers
    public var registry: PrometheusCollectorRegistry

    /// The default histogram buckets, to back a swift-metrics `Timer`.
    ///
    /// If there is no explicit overwrite via ``PrometheusMetricsFactory/timerHistogramBuckets``,
    /// the buckets provided here will be used for any new swift-metrics `Timer`.
    public var defaultTimerHistogramBuckets: [Double]

    /// The buckets for a ``Histogram`` per `Timer` name to back a swift-metrics `Timer`
    public var timerHistogramBuckets: [String: [Double]]

    /// The default histogram buckets, to back a swift-metrics `Recorder`, that aggregates.
    ///
    /// If there is no explicit overwrite via ``PrometheusMetricsFactory/recorderHistogramBuckets``,
    /// the buckets provided here will be used for any new swift-metrics `Recorder`, that aggregates.
    public var defaultRecorderHistogramBuckets: [Double]

    /// The buckets for a ``Histogram`` per `Recorder` name to back a swift-metrics `Recorder`, that aggregates.
    public var recorderHistogramBuckets: [String: [Double]]

    /// A closure to modify the name and labels used in the Swift Metrics API. This allows users
    /// to overwrite the Metric names in third party packages.
    public var nameAndLabelSanitizer: @Sendable (_ name: String, _ labels: [(String, String)]) -> (String, [(String, String)])

    public init(registry: PrometheusCollectorRegistry = Self.defaultRegistry) {
        self.registry = registry

        self.timerHistogramBuckets = [:]
        self.defaultTimerHistogramBuckets = [
            0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0,
        ]

        self.recorderHistogramBuckets = [:]
        self.defaultRecorderHistogramBuckets = [
            0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0,
        ]

        self.nameAndLabelSanitizer = { ($0, $1) }
    }
}

extension PrometheusMetricsFactory: CoreMetrics.MetricsFactory {
    public func makeCounter(label: String, dimensions: [(String, String)]) -> CoreMetrics.CounterHandler {
        let (label, dimensions) = self.nameAndLabelSanitizer(label, dimensions)
        return self.registry.makeCounter(name: label, labels: dimensions)
    }

    public func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler {
        let (label, dimensions) = self.nameAndLabelSanitizer(label, dimensions)
        return self.registry.makeCounter(name: label, labels: dimensions)
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> CoreMetrics.RecorderHandler {
        let (label, dimensions) = self.nameAndLabelSanitizer(label, dimensions)
        if aggregate {
            let buckets = self.recorderHistogramBuckets[label] ?? self.defaultRecorderHistogramBuckets
            return self.registry.makeHistogram(name: label, labels: dimensions, buckets: buckets)
        } else {
            return self.registry.makeGauge(name: label, labels: dimensions)
        }
    }

    public func makeMeter(label: String, dimensions: [(String, String)]) -> CoreMetrics.MeterHandler {
        return self.registry.makeGauge(name: label, labels: dimensions)
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> CoreMetrics.TimerHandler {
        let (label, dimensions) = self.nameAndLabelSanitizer(label, dimensions)
        let buckets = self.timerHistogramBuckets[label] ?? self.defaultTimerHistogramBuckets
        return self.registry.makeHistogram(name: label, labels: dimensions, buckets: buckets)
    }

    public func destroyCounter(_ handler: CoreMetrics.CounterHandler) {
        guard let counter = handler as? Counter else {
            return
        }
        self.registry.unregisterCounter(counter)
    }

    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {
        guard let counter = handler as? Counter else {
            return
        }
        self.registry.unregisterCounter(counter)
    }

    public func destroyRecorder(_ handler: CoreMetrics.RecorderHandler) {
        switch handler {
        case let gauge as Gauge:
            self.registry.unregisterGauge(gauge)
        case let histogram as Histogram:
            self.registry.unregisterHistogram(histogram)
        default:
            break
        }
    }

    public func destroyMeter(_ handler: CoreMetrics.MeterHandler) {
        guard let gauge = handler as? Gauge else {
            return
        }
        self.registry.unregisterGauge(gauge)
    }

    public func destroyTimer(_ handler: CoreMetrics.TimerHandler) {
        guard let histogram = handler as? Histogram else {
            return
        }
        self.registry.unregisterHistogram(histogram)
    }
}
