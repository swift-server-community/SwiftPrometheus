import CoreMetrics

private class MetricsCounter: CounterHandler {
    let counter: PromCounter<Int64, DimensionLabels>
    let labels: DimensionLabels?
    
    internal init(counter: PromCounter<Int64, DimensionLabels>, dimensions: [(String, String)]) {
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

private class MetricsGauge: RecorderHandler {
    let gauge: PromGauge<Double, DimensionLabels>
    let labels: DimensionLabels?
    
    internal init(gauge: PromGauge<Double, DimensionLabels>, dimensions: [(String, String)]) {
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
    let histogram: PromHistogram<Double, DimensionHistogramLabels>
    let labels: DimensionHistogramLabels?
    
    internal init(histogram: PromHistogram<Double, DimensionHistogramLabels>, dimensions: [(String, String)]) {
        self.histogram = histogram
        guard !dimensions.isEmpty else {
            labels = nil
            return
        }
        self.labels = DimensionHistogramLabels(dimensions)
    }
    
    func record(_ value: Int64) {
        histogram.observe(value.doubleValue, labels)
    }
    
    func record(_ value: Double) {
        histogram.observe(value, labels)
    }
}

class MetricsHistogramTimer: TimerHandler {
    let histogram: PromHistogram<Int64, DimensionHistogramLabels>
    let labels: DimensionHistogramLabels?

    init(histogram: PromHistogram<Int64, DimensionHistogramLabels>, dimensions: [(String, String)]) {
        self.histogram = histogram
        if !dimensions.isEmpty {
            self.labels = DimensionHistogramLabels(dimensions)
        } else {
            self.labels = nil
        }
    }

    func recordNanoseconds(_ duration: Int64) {
        return histogram.observe(duration, labels)
    }
}

private class MetricsSummary: TimerHandler {
    let summary: PromSummary<Int64, DimensionSummaryLabels>
    let labels: DimensionSummaryLabels?
    
    func preferDisplayUnit(_ unit: TimeUnit) {
        self.summary.preferDisplayUnit(unit)
    }
    
    internal init(summary: PromSummary<Int64, DimensionSummaryLabels>, dimensions: [(String, String)]) {
        self.summary = summary
        guard !dimensions.isEmpty else {
            labels = nil
            return
        }
        self.labels = DimensionSummaryLabels(dimensions)
    }
    
    func recordNanoseconds(_ duration: Int64) {
        return summary.observe(duration, labels)
    }
}

/// Used to sanitize labels into a format compatible with Prometheus label requirements.
/// Useful when using `PrometheusMetrics` via `SwiftMetrics` with clients which do not necessarily know 
/// about prometheus label formats, and may be using e.g. `.` or upper-case letters in labels (which Prometheus 
/// does not allow).
///
///     let sanitizer: LabelSanitizer = ...
///     let prometheusLabel = sanitizer.sanitize(nonPrometheusLabel)
///
/// By default `PrometheusLabelSanitizer` is used by `PrometheusMetricsFactory`
public protocol LabelSanitizer {
    /// Sanitize the passed in label to a Prometheus accepted value.
    ///
    /// - parameters:
    ///     - label: The created label that needs to be sanitized.
    ///
    /// - returns: A sanitized string that a Prometheus backend will accept.
    func sanitize(_ label: String) -> String
}

/// Default implementation of `LabelSanitizer` that sanitizes any characters not
/// allowed by Prometheus to an underscore (`_`).
///
/// See `https://prometheus.io/docs/concepts/data_model/#metric-names-and-labels` for more info.
public struct PrometheusLabelSanitizer: LabelSanitizer {
    private static let uppercaseAThroughZ = UInt8(ascii: "A") ... UInt8(ascii: "Z")
    private static let lowercaseAThroughZ = UInt8(ascii: "a") ... UInt8(ascii: "z")
    private static let zeroThroughNine = UInt8(ascii: "0") ... UInt8(ascii: "9")

    public init() { }

    public func sanitize(_ label: String) -> String {
        if PrometheusLabelSanitizer.isSanitized(label) {
            return label
        } else {
            return PrometheusLabelSanitizer.sanitizeLabel(label)
        }
    }

    /// Returns a boolean indicating whether the label is already sanitized.
    private static func isSanitized(_ label: String) -> Bool {
        return label.utf8.allSatisfy(PrometheusLabelSanitizer.isValidCharacter(_:))
    }
    
    /// Returns a boolean indicating whether the character may be used in a label.
    private static func isValidCharacter(_ codePoint: String.UTF8View.Element) -> Bool {
        switch codePoint {
        case PrometheusLabelSanitizer.lowercaseAThroughZ,
             PrometheusLabelSanitizer.zeroThroughNine,
             UInt8(ascii: ":"),
             UInt8(ascii: "_"):
            return true
        default:
            return false
        }
    }

    private static func sanitizeLabel(_ label: String) -> String {
        let sanitized: [UInt8] = label.utf8.map { character in
            if PrometheusLabelSanitizer.isValidCharacter(character) {
                return character
            } else {
                return PrometheusLabelSanitizer.sanitizeCharacter(character)
            }
        }
        
        return String(decoding: sanitized, as: UTF8.self)
    }
    
    private static func sanitizeCharacter(_ character: UInt8) -> UInt8 {
        if PrometheusLabelSanitizer.uppercaseAThroughZ.contains(character) {
            // Uppercase, so shift to lower case.
            return character + (UInt8(ascii: "a") - UInt8(ascii: "A"))
        } else {
            return UInt8(ascii: "_")
        }
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
        let counter = client.createCounter(forType: Int64.self, named: label, withLabelType: DimensionLabels.self)
        return MetricsCounter(counter: counter, dimensions: dimensions)
    }
    
    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        let label = configuration.labelSanitizer.sanitize(label)
        return aggregate ? makeHistogram(label: label, dimensions: dimensions) : makeGauge(label: label, dimensions: dimensions)
    }
    
    private func makeGauge(label: String, dimensions: [(String, String)]) -> RecorderHandler {
        let label = configuration.labelSanitizer.sanitize(label)
        let gauge = client.createGauge(forType: Double.self, named: label, withLabelType: DimensionLabels.self)
        return MetricsGauge(gauge: gauge, dimensions: dimensions)
    }
    
    private func makeHistogram(label: String, dimensions: [(String, String)]) -> RecorderHandler {
        let label = configuration.labelSanitizer.sanitize(label)
        let histogram = client.createHistogram(forType: Double.self, named: label, labels: DimensionHistogramLabels.self)
        return MetricsHistogram(histogram: histogram, dimensions: dimensions)
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
        let summary = client.createSummary(forType: Int64.self, named: label, quantiles: quantiles, labels: DimensionSummaryLabels.self)
        return MetricsSummary(summary: summary, dimensions: dimensions)
    }

    /// There's two different ways to back swift-api `Timer` with Prometheus classes.
    /// This method creates `Histogram` backed timer implementation
    private func makeHistogramTimer(label: String, dimensions: [(String, String)], buckets: Buckets) -> TimerHandler {
        let label = configuration.labelSanitizer.sanitize(label)
        let histogram = client.createHistogram(forType: Int64.self, named: label, buckets: buckets, labels: DimensionHistogramLabels.self)
        return MetricsHistogramTimer(histogram: histogram, dimensions: dimensions)
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
public struct DimensionLabels: MetricLabels {
    let dimensions: [(String, String)]
    
    public init() {
        self.dimensions = []
    }
    
    public init(_ dimensions: [(String, String)]) {
        self.dimensions = dimensions
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        for (key, value) in self.dimensions {
            try container.encode(value, forKey: .init(key))
        }
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

/// Helper for dimensions
/// swift-metrics api doesn't allow setting buckets explicitly.
/// If default buckets don't fit, this Labels implementation is a nice default to create Prometheus metric types with
public struct DimensionHistogramLabels: HistogramLabels {
    /// Bucket
    public var le: String
    /// Dimensions
    let labels: DimensionLabels
    
    /// Empty init
    public init() {
        self.le = ""
        self.labels = DimensionLabels()
    }
    
    /// Init with dimensions
    public init(_ dimensions: [(String, String)]) {
        self.le = ""
        self.labels = DimensionLabels(dimensions)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        for (key, value) in self.labels.dimensions {
            try container.encode(value, forKey: .init(key))
        }
        try container.encode(le, forKey: .init("le"))
    }
}

/// Helper for dimensions
public struct DimensionSummaryLabels: SummaryLabels {
    /// Quantile
    public var quantile: String
    /// Dimensions
    let labels: DimensionLabels

    /// Empty init
    public init() {
        self.quantile = ""
        self.labels = DimensionLabels()
    }
    
    /// Init with dimensions
    public init(_ dimensions: [(String, String)]) {
        self.quantile = ""
        self.labels = DimensionLabels(dimensions)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        for (key, value) in self.labels.dimensions {
            try container.encode(value, forKey: .init(key))
        }
        try container.encode(quantile, forKey: .init("quantile"))
    }
}
