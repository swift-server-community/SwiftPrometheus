import Prometheus
import Metrics
import NIO

let myProm = PrometheusClient()

MetricsSystem.bootstrap(PrometheusMetricsFactory(client: myProm))

//for _ in 0...Int.random(in: 10...100) {
//    let c = Counter(label: "test")
//    c.increment()
//}

for _ in 0...Int.random(in: 10...100) {
    let c = Counter(label: "test", dimensions: [("abc", "123")])
    c.increment()
}

//for _ in 0...Int.random(in: 100...500_000) {
//    let r = Recorder(label: "recorder")
//    r.record(Double.random(in: 0...20))
//}
//
//for _ in 0...Int.random(in: 100...500_000) {
//    let g = Gauge(label: "non_agg_recorder")
//    g.record(Double.random(in: 0...20))
//}
//
//for _ in 0...Int.random(in: 100...500_000) {
//    let t = Timer(label: "timer")
//    t.recordMicroseconds(Double.random(in: 20...150))
//}
//
//for _ in 0...Int.random(in: 100...500_000) {
//    let r = Recorder(label: "recorder", dimensions: [("abc", "123")])
//    r.record(Double.random(in: 0...20))
//}
//
//for _ in 0...Int.random(in: 100...500_000) {
//    let g = Gauge(label: "non_agg_recorder", dimensions: [("abc", "123")])
//    g.record(Double.random(in: 0...20))
//}
//
//for _ in 0...Int.random(in: 100...500_000) {
//    let t = Timer(label: "timer", dimensions: [("abc", "123")])
//    t.recordMicroseconds(Double.random(in: 20...150))
//}
//
//let codable1 = MyCodable(thing: "Thing1")
//let codable2 = MyCodable(thing: "Thing2")
//
//let counter = myProm.createCounter(forType: Int.self, named: "my_counter", helpText: "Just a counter", initialValue: 12)
//
//counter.inc(5)
//counter.inc(Int.random(in: 0...100), .init([("thing", "thing2")]))
//counter.inc(Int.random(in: 0...100), .init([("thing", "thing1")]))
//
//let gauge = myProm.createGauge(forType: Int.self, named: "my_gauge", helpText: "Just a gauge", initialValue: 12)
//
//gauge.inc(100)
//gauge.inc(Int.random(in: 0...100), .init([("thing", "thing2")]))
//gauge.inc(Int.random(in: 0...100), .init([("thing", "thing1")]))
//
//let histogram = myProm.createHistogram(forType: Double.self, named: "my_histogram", helpText: "Just a histogram")
//
//for _ in 0...Int.random(in: 10...50) {
//   histogram.observe(Double.random(in: 0...1))
//}
//
//for _ in 0...Int.random(in: 10...50) {
//   histogram.observe(Double.random(in: 0...1), .init([("route", "/test")]))
//}
//
//let summary = myProm.createSummary(forType: Double.self, named: "my_summary", helpText: "Just a summary")
//
//for _ in 0...Int.random(in: 100...1000) {
//   summary.observe(Double.random(in: 0...10000))
//}
//
//for _ in 0...Int.random(in: 100...1000) {
//    summary.observe(Double.random(in: 0...10000), .init([("route", "/test")]))
//}

let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let prom = elg.next().makePromise(of: String.self)

try! MetricsSystem.prometheus().collect(prom.succeed)

print(try! prom.futureResult.wait())
