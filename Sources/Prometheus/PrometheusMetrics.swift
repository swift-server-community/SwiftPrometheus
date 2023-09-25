import CoreMetrics

private class MetricsCounter: CounterHandler {
    let counter: PromCounter<Int64>
    let labels: DimensionLabels?

    internal init(counter: PromCounter<Int64>, dimensions: [(String, String)]) {
        self.counter = counter
        guard !dimensions.isEmpty else {
            labels = nil
            return
        }
        self.labels = DimensionLabels(dimensions)
    }

    func increment(by: Int64) {
        self.counter.inc(by, labels)
    }

    func reset() { }
}

private class MetricsFloatingPointCounter: FloatingPointCounterHandler {
    let counter: PromCounter<Double>
    let labels: DimensionLabels?

    internal init(counter: PromCounter<Double>, dimensions: [(String, String)]) {
        self.counter = counter
        guard !dimensions.isEmpty else {
            labels = nil
            return
        }
        self.labels = DimensionLabels(dimensions)
    }

    func increment(by: Double) {
        self.counter.inc(by, labels)
    }

    func reset() { }
}

private class MetricsGauge: RecorderHandler {
    let gauge: PromGauge<Double>
    let labels: DimensionLabels?

    internal init(gauge: PromGauge<Double>, dimensions: [(String, String)]) {
        self.gauge = gauge
        guard !dimensions.isEmpty else {
            labels = nil
            return
        }
        self.labels = DimensionLabels(dimensions)
    }

    func record(_ value: Int64) {
        self.record(value.doubleValue)
    }

    func record(_ value: Double) {
        gauge.set(value, labels)
    }
}

private class MetricsHistogram: RecorderHandler {
    let histogram: PromHistogram<Double>
    let labels: DimensionLabels?

    internal init(histogram: PromHistogram<Double>, dimensions: [(String, String)]) {
        self.histogram = histogram
        guard !dimensions.isEmpty else {
            labels = nil
            return
        }
        self.labels = DimensionLabels(dimensions)
    }

    func record(_ value: Int64) {
        histogram.observe(value.doubleValue, labels)
    }

    func record(_ value: Double) {
        histogram.observe(value, labels)
    }
}

class MetricsHistogramTimer: TimerHandler {
    let histogram: PromHistogram<Int64>
    let labels: DimensionLabels?

    init(histogram: PromHistogram<Int64>, dimensions: [(String, String)]) {
        self.histogram = histogram
        if !dimensions.isEmpty {
            self.labels = DimensionLabels(dimensions)
        } else {
            self.labels = nil
        }
    }

    func recordNanoseconds(_ duration: Int64) {
        return histogram.observe(duration, labels)
    }
}

private class MetricsSummary: TimerHandler {
    let summary: PromSummary<Int64>
    let labels: DimensionLabels?

    func preferDisplayUnit(_ unit: TimeUnit) {
        self.summary.preferDisplayUnit(unit)
    }

    internal init(summary: PromSummary<Int64>, dimensions: [(String, String)]) {
        self.summary = summary
        guard !dimensions.isEmpty else {
            labels = nil
            return
        }
        self.labels = DimensionLabels(dimensions)
    }

    func recordNanoseconds(_ duration: Int64) {
        return summary.observe(duration, labels)
    }
}

/// Defines the base for a bridge between PrometheusClient and swift-metrics.
/// Used by `SwiftMetrics.prometheus()` to get an instance of `PrometheusClient` from `MetricsSystem`
///
/// Any custom implementation of `MetricsFactory` using `PrometheusClient` should conform to this implementation.
public protocol PrometheusWrappedMetricsFactory: MetricsFactory {
    var client: PrometheusClient { get }
}

/// A bridge between PrometheusClient and swift-metrics. Prometheus types don't map perfectly on swift-metrics API,
/// which makes bridge implementation non trivial. This class defines how exactly swift-metrics types should be backed
/// with Prometheus types, e.g. how to sanitize labels, what buckets/quantiles to use for recorder/timer, etc.
public struct PrometheusMetricsFactory: PrometheusWrappedMetricsFactory {

    /// Prometheus client to bridge swift-metrics API to.
    public let client: PrometheusClient

    /// Bridge configuration.
    private let configuration: Configuration

    public init(client: PrometheusClient,
                configuration: Configuration = Configuration()) {
        self.client = client
        self.configuration = configuration
    }

    public func destroyCounter(_ handler: CounterHandler) {
        guard let handler = handler as? MetricsCounter else { return }
        client.removeMetric(handler.counter)
    }

    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {
        guard let handler = handler as? MetricsFloatingPointCounter else { return }
        client.removeMetric(handler.counter)
    }

    public func destroyRecorder(_ handler: RecorderHandler) {
        if let handler = handler as? MetricsGauge {
            client.removeMetric(handler.gauge)
        }
        if let handler = handler as? MetricsHistogram {
            client.removeMetric(handler.histogram)
        }
    }

    public func destroyTimer(_ handler: TimerHandler) {
        switch self.configuration.timerImplementation._wrapped {
        case .summary:
            guard let handler = handler as? MetricsSummary else { return }
            client.removeMetric(handler.summary)
        case .histogram:
            guard let handler = handler as? MetricsHistogramTimer else { return }
            client.removeMetric(handler.histogram)
        }
    }

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        let label = configuration.labelSanitizer.sanitize(label)
        let counter = client.createCounter(forType: Int64.self, named: label)
        return MetricsCounter(counter: counter, dimensions: dimensions.sanitized())
    }

    public func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler {
        let label = configuration.labelSanitizer.sanitize(label)
        let counter = client.createCounter(forType: Double.self, named: label)
        return MetricsFloatingPointCounter(counter: counter, dimensions: dimensions.sanitized())
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        let label = configuration.labelSanitizer.sanitize(label)
        return aggregate ? makeHistogram(label: label, dimensions: dimensions) : makeGauge(label: label, dimensions: dimensions)
    }

    private func makeGauge(label: String, dimensions: [(String, String)]) -> RecorderHandler {
        let label = configuration.labelSanitizer.sanitize(label)
        let gauge = client.createGauge(forType: Double.self, named: label)
        return MetricsGauge(gauge: gauge, dimensions: dimensions.sanitized())
    }

    private func makeHistogram(label: String, dimensions: [(String, String)]) -> RecorderHandler {
        let label = configuration.labelSanitizer.sanitize(label)
        let histogram = client.createHistogram(forType: Double.self, named: label, buckets: configuration.defaultRecorderBuckets)
        return MetricsHistogram(histogram: histogram, dimensions: dimensions.sanitized())
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        switch configuration.timerImplementation._wrapped {
        case .summary(let quantiles):
            return self.makeSummaryTimer(label: label, dimensions: dimensions, quantiles: quantiles)
        case .histogram(let buckets):
            return self.makeHistogramTimer(label: label, dimensions: dimensions, buckets: buckets)
        }
    }

    /// There's two different ways to back swift-api `Timer` with Prometheus classes.
    /// This method creates `Summary` backed timer implementation
    private func makeSummaryTimer(label: String, dimensions: [(String, String)], quantiles: [Double]) -> TimerHandler {
        let label = configuration.labelSanitizer.sanitize(label)
        let summary = client.createSummary(forType: Int64.self, named: label, quantiles: quantiles)
        return MetricsSummary(summary: summary, dimensions: dimensions.sanitized())
    }

    /// There's two different ways to back swift-api `Timer` with Prometheus classes.
    /// This method creates `Histogram` backed timer implementation
    private func makeHistogramTimer(label: String, dimensions: [(String, String)], buckets: Buckets) -> TimerHandler {
        let label = configuration.labelSanitizer.sanitize(label)
        let histogram = client.createHistogram(forType: Int64.self, named: label, buckets: buckets)
        return MetricsHistogramTimer(histogram: histogram, dimensions: dimensions.sanitized())
    }
}

extension Array where Element == (String, String) {
    func sanitized() -> [(String, String)] {
        let sanitizer = DimensionsSanitizer()
        return self.map {
            (sanitizer.sanitize($0.0), $0.1)
        }
    }
}

public extension MetricsSystem {
    /// Get the bootstrapped `MetricsSystem` as `PrometheusClient`
    ///
    /// - Returns: `PrometheusClient` used to bootstrap `MetricsSystem`
    /// - Throws: `PrometheusError.PrometheusFactoryNotBootstrapped`
    ///             if no `PrometheusClient` was used to bootstrap `MetricsSystem`
    static func prometheus() throws -> PrometheusClient {
        guard let prom = self.factory as? PrometheusWrappedMetricsFactory else {
            throw PrometheusError.prometheusFactoryNotBootstrapped(bootstrappedWith: "\(self.factory)")
        }
        return prom.client
    }
}

// MARK: - Labels

/// A generic `String` based `CodingKey` implementation.
private struct StringCodingKey: CodingKey {
    /// `CodingKey` conformance.
    public var stringValue: String

    /// `CodingKey` conformance.
    public var intValue: Int? {
        return Int(self.stringValue)
    }

    /// Creates a new `StringCodingKey`.
    public init(_ string: String) {
        self.stringValue = string
    }

    /// `CodingKey` conformance.
    public init(stringValue: String) {
        self.stringValue = stringValue
    }

    /// `CodingKey` conformance.
    public init(intValue: Int) {
        self.stringValue = intValue.description
    }
}

/// Helper for dimensions
public struct DimensionLabels: Hashable, ExpressibleByArrayLiteral {
    let dimensions: [(String, String)]

    public init() {
        self.dimensions = []
    }

    public init(_ dimensions: [(String, String)]) {
        self.dimensions = dimensions
    }

    public init(arrayLiteral elements: (String, String)...) {
        self.init(elements)
    }

    public func hash(into hasher: inout Hasher) {
        for (key, value) in dimensions {
            hasher.combine(key)
            hasher.combine(value)
        }
    }

    public static func == (lhs: DimensionLabels, rhs: DimensionLabels) -> Bool {
        guard lhs.dimensions.count == rhs.dimensions.count else { return false }
        for index in 0..<lhs.dimensions.count {
            guard lhs.dimensions[index] == rhs.dimensions[index] else { return false }
        }
        return true
    }
}

extension DimensionLabels: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        for (key, value) in self.dimensions {
            try container.encode(value, forKey: .init(key))
        }
    }
}



/// Helper for dimensions
/// swift-metrics api doesn't allow setting buckets explicitly.
/// If default buckets don't fit, this Labels implementation is a nice default to create Prometheus metric types with
struct EncodableHistogramLabels: Encodable {
    /// Bucket
    let le: String?
    /// Dimensions
    let labels: DimensionLabels?

    public init(labels: DimensionLabels?, le: String? = nil) {
        self.le = le
        self.labels = labels
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        if let labels = labels {
            for (key, value) in labels.dimensions {
                try container.encode(value, forKey: .init(key))
            }
        }
        if let le = le {
            try container.encode(le, forKey: .init("le"))
        }
    }
}

struct EncodableSummaryLabels: Encodable {
    /// Quantile
    var quantile: String?
    /// Dimensions
    let labels: DimensionLabels?

    public init(labels: DimensionLabels?, quantile: String?) {
        self.quantile = quantile
        self.labels = labels
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        if let labels = labels {
            for (key, value) in labels.dimensions {
                try container.encode(value, forKey: .init(key))
            }
        }
        if let quantile = quantile {
            try container.encode(quantile, forKey: .init("quantile"))
        }
    }
}
