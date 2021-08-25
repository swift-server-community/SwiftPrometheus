import NIOConcurrencyHelpers
import Dispatch

/// Buckets are used by Histograms to bucket their values.
///
/// See https://prometheus.io/docs/concepts/metric_types/#Histogram
public struct Buckets: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Double

    public init(arrayLiteral elements: Double...) {
        self.init(elements)
    }

    fileprivate init(_ r: [Double]) {
        if r.isEmpty {
            self = Buckets.defaultBuckets
            return
        }
        var r = r
        if !r.contains(Double.greatestFiniteMagnitude) {
            r.append(Double.greatestFiniteMagnitude)
        }
        assert(r == r.sorted(by: <), "Buckets are not in increasing order")
        assert(Array(Set(r)).sorted(by: <) == r.sorted(by: <), "Buckets contain duplicate values.")
        self.buckets = r
    }

    /// The upper bounds
    public let buckets: [Double]

    /// Default buckets used by Histograms
    public static let defaultBuckets: Buckets = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]

    /// Create linear buckets used by Histograms
    ///
    /// - Parameters:
    ///     - start: Start value for your buckets. This will be the upper bound of your first bucket.
    ///     - width: Width of each bucket.
    ///     - count: Amount of buckets to generate, should be larger than zero. The +Inf bucket is not included in this count.
    public static func linear(start: Double, width: Double, count: Int) -> Buckets {
        assert(count >= 1, "Bucket.linear needs a count larger than 1")
        let arr = (0..<count).map { Double(start) + Double($0) * Double(width) }
        return Buckets(arr)
    }

    /// Create exponential buckets used by Histograms
    ///
    ///  - Parameters:
    ///     - start: Start value for your buckets, should be larger than 0. This will be the upper bound of your first bucket.
    ///     - factor: Factor to increase each upper bound by, based on the upper bound of the last bucket. Should be larger than 1.
    ///     - count: Amount of buckets to generate, should be larger than zero. The +Inf bucket is not included in this count.
    public static func exponential(start: Double, factor: Double, count: Int) -> Buckets {
        assert(count > 1, "Bucket.exponential needs a count greater than 1")
        assert(start > 0, "Bucket.exponential needs a start larger than 0")
        assert(factor > 1, "Bucket.exponential needs a factor larger than 1")
        var arr = [Double]()
        var s = start
        for _ in 0..<count {
            arr.append(s)
            s *= factor
        }
        return Buckets(arr)
    }
}

/// Label type Histograms can use
public protocol HistogramLabels: MetricLabels {
    /// Bucket
    var le: String { get set }
}

extension HistogramLabels {
    /// Creates empty HistogramLabels
    init() {
        self.init()
        self.le = ""
    }
}

/// Prometheus Histogram metric
///
/// See https://prometheus.io/docs/concepts/metric_types/#Histogram
public class PromHistogram<NumType: DoubleRepresentable, Labels: HistogramLabels>: PromMetric, PrometheusHandled {
    /// Prometheus instance that created this Histogram
    internal weak var prometheus: PrometheusClient?

    /// Name of this Histogram, required
    public let name: String
    /// Help text of this Histogram, optional
    public let help: String?

    /// Type of the metric, used for formatting
    public let _type: PromMetricType = .histogram

    /// Bucketed values for this Histogram
    private var buckets: [PromCounter<NumType, EmptyLabels>] = []

    /// Buckets used by this Histogram
    internal let upperBounds: [Double]

    /// Labels for this Histogram
    internal let labels: Labels

    /// Sub Histograms for this Histogram
    fileprivate var subHistograms: [Labels: PromHistogram<NumType, Labels>] = [:]

    /// Total value of the Histogram
    private let sum: PromCounter<NumType, EmptyLabels>

    /// Lock used for thread safety
    private let lock: Lock

    /// Creates a new Histogram
    ///
    /// - Parameters:
    ///     - name: Name of the Histogram
    ///     - help: Help text of the Histogram
    ///     - labels: Labels for the Histogram
    ///     - buckets: Buckets to use for the Histogram
    ///     - p: Prometheus instance creating this Histogram
    internal init(_ name: String, _ help: String? = nil, _ labels: Labels = Labels(), _ buckets: Buckets = .defaultBuckets, _ p: PrometheusClient) {
        self.name = name
        self.help = help

        self.prometheus = p

        self.sum = .init("\(self.name)_sum", nil, 0, p)

        self.labels = labels

        self.upperBounds = buckets.buckets

        self.lock = Lock()

        buckets.buckets.forEach { _ in
            self.buckets.append(.init("\(name)_bucket", nil, 0, p))
        }
    }

    /// Gets the metric string for this Histogram
    ///
    /// - Returns:
    ///     Newline separated Prometheus formatted metric string
    public func collect() -> String {
        let (buckets, subHistograms, labels) = self.lock.withLock {
            (self.buckets, self.subHistograms, self.labels)
        }

        var output = [String]()
        // HELP/TYPE + (histogram + subHistograms) * (buckets + sum + count)
        output.reserveCapacity(2 + (subHistograms.count + 1) * (buckets.count + 2))

        if let help = self.help {
            output.append("# HELP \(self.name) \(help)")
        }
        output.append("# TYPE \(self.name) \(self._type)")
        collectBuckets(buckets: buckets,
                       upperBounds: self.upperBounds,
                       name: self.name,
                       labels: labels,
                       sum: self.sum.get(),
                       into: &output)

        subHistograms.forEach { subHistogram in
            let (subHistogramBuckets, subHistogramLabels) = self.lock.withLock {
                (subHistogram.value.buckets, subHistogram.value.labels)
            }
            collectBuckets(buckets: subHistogramBuckets,
                           upperBounds: subHistogram.value.upperBounds,
                           name: subHistogram.value.name,
                           labels: subHistogramLabels,
                           sum: subHistogram.value.sum.get(),
                           into: &output)
        }
        return output.joined(separator: "\n")
    }

    private func collectBuckets(buckets: [PromCounter<NumType, EmptyLabels>],
                                upperBounds: [Double],
                                name: String,
                                labels: Labels,
                                sum: NumType,
                                into output: inout [String]) {
        var labels = labels
        var acc: NumType = 0
        for (i, bound) in upperBounds.enumerated() {
            acc += buckets[i].get()
            labels.le = bound.description
            let labelsString = encodeLabels(labels)
            output.append("\(name)_bucket\(labelsString) \(acc)")
        }

        let labelsString = encodeLabels(labels, ["le"])
        output.append("\(name)_count\(labelsString) \(acc)")

        output.append("\(name)_sum\(labelsString) \(sum)")
    }

    /// Observe a value
    ///
    /// - Parameters:
    ///     - value: Value to observe
    ///     - labels: Labels to attach to the observed value
    public func observe(_ value: NumType, _ labels: Labels? = nil) {
        if let labels = labels, type(of: labels) != type(of: EmptyHistogramLabels()) {
            self.getOrCreateHistogram(with: labels)
                .observe(value)
        }
        self.sum.inc(value)

        for (i, bound) in self.upperBounds.enumerated() {
            if bound >= value.doubleValue {
                self.buckets[i].inc()
                return
            }
        }
    }

    /// Time the duration of a closure and observe the resulting time in seconds.
    ///
    /// - parameters:
    ///     - labels: Labels to attach to the resulting value.
    ///     - body: Closure to run & record.
    @inlinable
    public func time<T>(_ labels: Labels? = nil, _ body: @escaping () throws -> T) rethrows -> T {
        let start = DispatchTime.now().uptimeNanoseconds
        defer {
            let delta = Double(DispatchTime.now().uptimeNanoseconds - start)
            self.observe(.init(delta / 1_000_000_000), labels)
        }
        return try body()
    }

    /// Helper for histograms & labels
    fileprivate func getOrCreateHistogram(with labels: Labels) -> PromHistogram<NumType, Labels> {
        let subHistograms = lock.withLock { self.subHistograms }
        if let histogram = subHistograms[labels] {
            if histogram.name == self.name, histogram.help == self.help {
                return histogram
            } else {
                fatalError("Somehow got 2 summaries with the same data type")
            }
        } else {
            return lock.withLock {
                if let histogram = subHistograms[labels], histogram.name == self.name, histogram.help == self.help {
                    return histogram
                }
                guard let prometheus = prometheus else { fatalError("Lingering Histogram") }
                let newHistogram = PromHistogram(self.name, self.help, labels, Buckets(self.upperBounds), prometheus)
                self.subHistograms[labels] = newHistogram
                return newHistogram
            }
        }
    }
}
