import struct Foundation.Date
import Dispatch
import NIOConcurrencyHelpers

/// Prometheus Gauge metric
///
/// See https://prometheus.io/docs/concepts/metric_types/#gauge
public class PromGauge<NumType: DoubleRepresentable>: PromMetric {
    /// Name of the Gauge, required
    public let name: String
    /// Help text of the Gauge, optional
    public let help: String?
    
    /// Type of the metric, used for formatting
    public let _type: PromMetricType = .gauge
    
    /// Current value of the counter
    private var value: NumType
    
    /// Initial value of the Gauge
    private let initialValue: NumType

    /// Indicates wether or not metric has been used without labels
    private var usedWithoutLabels: Bool

    /// Storage of values that have labels attached
    private var metrics: [DimensionLabels: NumType] = [:]
    
    /// Lock used for thread safety
    private let lock: Lock
    
    /// Creates a new instance of a Gauge
    ///
    /// - Parameters:
    ///     - name: Name of the Gauge
    ///     - help: Help text of the Gauge
    ///     - initialValue: Initial value to set the Gauge to
    ///     - p: Prometheus instance that created this Gauge
    ///
    internal init(_ name: String, _ help: String? = nil, _ initialValue: NumType = 0) {
        self.name = name
        self.help = help
        self.initialValue = initialValue
        self.value = initialValue
        self.usedWithoutLabels = initialValue != 0
        self.lock = Lock()
    }
    
    /// Gets the metric string for this Gauge
    ///
    /// - Returns:
    ///     Newline separated Prometheus formatted metric string
    public func collect() -> String {
        let (value, metrics, usedWithoutLabels) = self.lock.withLock {
            (self.value, self.metrics, self.usedWithoutLabels)
        }
        var output = [String]()

        if let help = self.help {
            output.append("# HELP \(self.name) \(help)")
        }
        output.append("# TYPE \(self.name) \(self._type)")

        if usedWithoutLabels {
            output.append("\(self.name) \(value)")
        }

        metrics.forEach { (labels, value) in
            let labelsString = encodeLabels(labels)
            output.append("\(self.name)\(labelsString) \(value)")
        }

        return output.joined(separator: "\n")
    }
    
    /// Sets the Gauge to the current unix-time in seconds
    ///
    /// - Parameters:
    ///     - labels: Labels to attach to the value
    ///
    /// - Returns: The value of the Gauge attached to the provided labels
    @discardableResult
    public func setToCurrentTime(_ labels: DimensionLabels? = nil) -> NumType {
        return self.set(.init(Date().timeIntervalSince1970), labels)
    }
    
    /// Tracks in progress blocks of code or functions.
    ///
    ///     func someFunc() -> String { return "ABC" }
    ///     let newFunc = myGauge.trackInProgress(someFunc)
    ///     newFunc() // returns "ABC" and increments & decrements Gauge
    ///
    /// - Parameters:
    ///     - labels: Labels to attach to the value
    ///     - body: Function to wrap progress tracker around
    ///
    /// - Returns: The same type of function passed in for `body`, but wrapped to track progress.
    @inlinable
    public func trackInProgress<T>(_ labels: DimensionLabels? = nil, _ body: @escaping () throws -> T) -> (() throws -> T) {
        return {
            self.inc()
            defer {
                self.dec()
            }
            return try body()
        }
    }
    /// Time the execution duration of a closure and observe the resulting time in seconds.
    ///
    /// - parameters:
    ///     - labels: Labels to attach to the resulting value.
    ///     - body: Closure to run & record execution time of.
    @inlinable
    public func time<T>(_ labels: DimensionLabels? = nil, _ body: @escaping () throws -> T) rethrows -> T {
        let start = DispatchTime.now().uptimeNanoseconds
        defer {
            let delta = Double(DispatchTime.now().uptimeNanoseconds - start)
            self.set(.init(delta / 1_000_000_000), labels)
        }
        return try body()
    }
    
    
    /// Sets the Gauge
    ///
    /// - Parameters:
    ///     - amount: Amount to set the gauge to
    ///     - labels: Labels to attach to the value
    ///
    /// - Returns: The value of the Gauge attached to the provided labels
    @discardableResult
    public func set(_ amount: NumType, _ labels: DimensionLabels? = nil) -> NumType {
        return self.lock.withLock {
            if let labels = labels {
                self.metrics[labels] = amount
                return amount
            } else {
                self.usedWithoutLabels = true
                self.value = amount
                return self.value
            }
        }
    }
    
    /// Increments the Gauge
    ///
    /// - Parameters:
    ///     - amount: Amount to increment the Gauge with
    ///     - labels: Labels to attach to the value
    ///
    /// - Returns: The value of the Gauge attached to the provided labels
    @discardableResult
    public func inc(_ amount: NumType, _ labels: DimensionLabels? = nil) -> NumType {
        return self.lock.withLock {
            if let labels = labels {
                var val = self.metrics[labels] ?? self.initialValue
                val += amount
                self.metrics[labels] = val
                return val
            } else {
                self.usedWithoutLabels = true
                self.value += amount
                return self.value
            }
        }
    }
    
    /// Increments the Gauge
    ///
    /// - Parameters:
    ///     - labels: Labels to attach to the value
    ///
    /// - Returns: The value of the Gauge attached to the provided labels
    @discardableResult
    public func inc(_ labels: DimensionLabels? = nil) -> NumType {
        return self.inc(1, labels)
    }
    
    /// Decrements the Gauge
    ///
    /// - Parameters:
    ///     - amount: Amount to decrement the Gauge with
    ///     - labels: Labels to attach to the value
    ///
    /// - Returns: The value of the Gauge attached to the provided labels
    @discardableResult
    public func dec(_ amount: NumType, _ labels: DimensionLabels? = nil) -> NumType {
        return self.lock.withLock {
            if let labels = labels {
                var val = self.metrics[labels] ?? self.initialValue
                val -= amount
                self.metrics[labels] = val
                return val
            } else {
                self.usedWithoutLabels = true
                self.value -= amount
                return self.value
            }
        }
    }
    
    /// Decrements the Gauge
    ///
    /// - Parameters:
    ///     - labels: Labels to attach to the value
    ///
    /// - Returns: The value of the Gauge attached to the provided labels
    @discardableResult
    public func dec(_ labels: DimensionLabels? = nil) -> NumType {
        return self.dec(1, labels)
    }
    
    /// Gets the value of the Gauge
    ///
    /// - Parameters:
    ///     - labels: Labels to get the value for
    ///
    /// - Returns: The value of the Gauge attached to the provided labels
    public func get(_ labels: DimensionLabels? = nil) -> NumType {
        return self.lock.withLock {
            if let labels = labels {
                return self.metrics[labels] ?? initialValue
            } else {
                return self.value
            }
        }
    }
}
