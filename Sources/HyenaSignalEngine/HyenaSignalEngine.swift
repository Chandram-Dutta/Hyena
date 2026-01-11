import Foundation
import HyenaGraphBuilder

public struct HyenaSignalEngine {
    public init() {}

    public func runSignals(on graphs: GraphResult) throws -> SignalResult {
        var signals: [Signal] = []

        let deadFiles = findDeadFiles(in: graphs.fileDependencyGraph)
        signals.append(contentsOf: deadFiles)

        let circularDeps = findCircularDependencies(in: graphs.fileDependencyGraph)
        signals.append(contentsOf: circularDeps)

        return SignalResult(signals: signals)
    }

    private func findDeadFiles(in graph: FileDependencyGraph) -> [Signal] {
        var signals: [Signal] = []

        let importedModules = graph.allImportedModules
        let localModules = Set(graph.nodes.map { $0.moduleName })

        for node in graph.nodes {
            let isImportedByAnyone = importedModules.contains(node.moduleName)
            let isExternalImport = !localModules.contains(node.moduleName)

            if !isImportedByAnyone && !isExternalImport {
                let hasOutgoingImports = !graph.outgoingEdges(for: node.path).isEmpty
                let severity: Severity = hasOutgoingImports ? .warning : .info

                signals.append(Signal(
                    name: "dead-file",
                    severity: severity,
                    message: "File '\(node.moduleName)' is not imported by any other file",
                    file: node.path
                ))
            }
        }

        return signals
    }

    private func findCircularDependencies(in graph: FileDependencyGraph) -> [Signal] {
        let cycles = graph.findCycles()

        return cycles.map { cycle in
            let fileNames = cycle.map { ($0 as NSString).lastPathComponent }
            let cycleDescription = fileNames.joined(separator: " → ")

            return Signal(
                name: "circular-dependency",
                severity: .error,
                message: "Circular dependency detected: \(cycleDescription)",
                file: cycle.first
            )
        }
    }
}

public struct SignalResult {
    public let signals: [Signal]

    public init(signals: [Signal]) {
        self.signals = signals
    }

    public func signals(named name: String) -> [Signal] {
        signals.filter { $0.name == name }
    }

    public func signals(withSeverity severity: Severity) -> [Signal] {
        signals.filter { $0.severity == severity }
    }
}

public struct Signal {
    public let name: String
    public let severity: Severity
    public let message: String
    public let file: String?

    public init(name: String, severity: Severity, message: String, file: String? = nil) {
        self.name = name
        self.severity = severity
        self.message = message
        self.file = file
    }
}

public enum Severity: String {
    case info
    case warning
    case error
}
