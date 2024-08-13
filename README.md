# Swift Prometheus

[![sswg:sandbox](https://img.shields.io/badge/sswg-sandbox-yellow.svg)][SSWG-Incubation]
[![Documentation](http://img.shields.io/badge/read_the-docs-2196f3.svg)][Documentation]

A Swift client for the [Prometheus](https://github.com/prometheus/prometheus) monitoring system,
supporting counters, gauges and histograms. Swift Prometheus 
implements the Swift Metrics API.

## Security

Please see [SECURITY.md](SECURITY.md) for details on the security process.

## Contributing

All contributions are most welcome!

If you think of some cool new feature that should be included, please [create an issue](https://github.com/swift-server/swift-prometheus/issues/new). 
Or, if you want to implement it yourself, [fork this repo](https://github.com/swift-server/swift-prometheus/fork) and submit a PR!

If you find a bug or have issues, please [create an issue](https://github.com/swift-server-community/SwiftPrometheus/issues/new) explaining your problems. Please include as much information as possible, so it's easier for us to reproduce (Framework, OS, Swift version, terminal output, etc.)

[Documentation]: https://swiftpackageindex.com/swift-server/swift-prometheus/documentation/prometheus
[SSWG-Incubation]: https://www.swift.org/sswg/incubation-process.html


## Benchmarks

Benchmarks for `swift-prometheus` are in a separate Swift Package in the `Benchmarks` subfolder of this repository.
They use the [`package-benchmark`](https://github.com/ordo-one/package-benchmark) plugin.
Benchmarks depends on the [`jemalloc`](https://jemalloc.net) memory allocation library, which is used by `package-benchmark` to capture memory allocation statistics.
An installation guide can be found in the [Getting Started article](https://swiftpackageindex.com/ordo-one/package-benchmark/documentation/benchmark/gettingstarted#Installing-Prerequisites-and-Platform-Support) of `package-benchmark`.
Afterwards you can run the benchmarks from CLI by going to the `Benchmarks` subfolder (e.g. `cd Benchmarks`) and invoking:
```
swift package benchmark
```

For more information please refer to `swift package benchmark --help` or the [documentation of `package-benchmark`](https://swiftpackageindex.com/ordo-one/package-benchmark/documentation/benchmark). 
