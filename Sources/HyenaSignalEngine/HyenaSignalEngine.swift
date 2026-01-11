import Foundation
import HyenaGraphBuilder

public struct HyenaSignalEngine {
    public init() {}

    public func runSignals(on graphs: GraphResult) throws -> SignalResult {
        return SignalResult(signals: [])
    }
}

public struct SignalResult {
    public let signals: [Signal]

    public init(signals: [Signal]) {
        self.signals = signals
    }
}

public struct Signal {
    public let name: String
    public let severity: Severity
    public let message: String

    public init(name: String, severity: Severity, message: String) {
        self.name = name
        self.severity = severity
        self.message = message
    }
}

public enum Severity {
    case info
    case warning
    case error
}
