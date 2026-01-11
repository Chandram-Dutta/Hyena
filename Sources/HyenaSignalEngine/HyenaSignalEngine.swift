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

        let blastRadius = findHighBlastRadius(in: graphs.fileDependencyGraph)
        signals.append(contentsOf: blastRadius)

        let centralFiles = findCentralFiles(in: graphs.fileDependencyGraph)
        signals.append(contentsOf: centralFiles)

        let godFiles = findGodFiles(in: graphs.fileDependencyGraph)
        signals.append(contentsOf: godFiles)

        let deepChains = findDeepChains(in: graphs.fileDependencyGraph)
        signals.append(contentsOf: deepChains)

        // Inheritance graph signals
        let deepHierarchies = findDeepHierarchies(in: graphs.inheritanceGraph)
        signals.append(contentsOf: deepHierarchies)

        let wideProtocols = findWideProtocols(in: graphs.inheritanceGraph)
        signals.append(contentsOf: wideProtocols)

        // Call graph signals
        let hotFunctions = findHotFunctions(in: graphs.callGraph)
        signals.append(contentsOf: hotFunctions)

        let unusedFunctions = findUnusedFunctions(in: graphs.callGraph)
        signals.append(contentsOf: unusedFunctions)

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

    private func findHighBlastRadius(in graph: FileDependencyGraph, threshold: Int = 5) -> [Signal] {
        var signals: [Signal] = []
        let moduleToPath = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.moduleName, $0.path) })

        for node in graph.nodes {
            let dependents = computeTransitiveDependents(for: node.path, in: graph, moduleToPath: moduleToPath)
            if dependents.count >= threshold {
                let severity: Severity = dependents.count >= 10 ? .error : .warning
                signals.append(Signal(
                    name: "blast-radius",
                    severity: severity,
                    message: "File has \(dependents.count) transitive dependents - changes here are risky",
                    file: node.path
                ))
            }
        }
        return signals
    }

    private func computeTransitiveDependents(
        for path: String,
        in graph: FileDependencyGraph,
        moduleToPath: [String: String]
    ) -> Set<String> {
        var visited: Set<String> = []
        var queue: [String] = [path]

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let currentModule = ((current as NSString).lastPathComponent as NSString).deletingPathExtension

            for node in graph.nodes {
                if visited.contains(node.path) { continue }
                let imports = graph.outgoingEdges(for: node.path).map { $0.to }
                if imports.contains(currentModule) {
                    visited.insert(node.path)
                    queue.append(node.path)
                }
            }
        }

        visited.remove(path)
        return visited
    }

    private func findCentralFiles(in graph: FileDependencyGraph, threshold: Int = 5) -> [Signal] {
        var signals: [Signal] = []

        for node in graph.nodes {
            let inDegree = graph.incomingEdges(for: node.path).count
            if inDegree >= threshold {
                let severity: Severity = inDegree >= 10 ? .error : .warning
                signals.append(Signal(
                    name: "central-file",
                    severity: severity,
                    message: "File is imported by \(inDegree) files - potential bottleneck",
                    file: node.path
                ))
            }
        }
        return signals
    }

    private func findGodFiles(in graph: FileDependencyGraph, threshold: Int = 10) -> [Signal] {
        var signals: [Signal] = []

        for node in graph.nodes {
            let outDegree = graph.outgoingEdges(for: node.path).count
            if outDegree >= threshold {
                let severity: Severity = outDegree >= 15 ? .error : .warning
                signals.append(Signal(
                    name: "god-file",
                    severity: severity,
                    message: "File imports \(outDegree) modules - may be doing too much",
                    file: node.path
                ))
            }
        }
        return signals
    }

    private func findDeepChains(in graph: FileDependencyGraph, threshold: Int = 5) -> [Signal] {
        var signals: [Signal] = []
        let moduleToPath = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.moduleName, $0.path) })
        var memo: [String: Int] = [:]

        for node in graph.nodes {
            let depth = computeMaxDepth(for: node.path, in: graph, moduleToPath: moduleToPath, visited: [], memo: &memo)
            if depth >= threshold {
                let severity: Severity = depth >= 8 ? .error : .warning
                signals.append(Signal(
                    name: "deep-chain",
                    severity: severity,
                    message: "File has dependency chain of depth \(depth) - fragile architecture",
                    file: node.path
                ))
            }
        }
        return signals
    }

    private func computeMaxDepth(
        for path: String,
        in graph: FileDependencyGraph,
        moduleToPath: [String: String],
        visited: [String],
        memo: inout [String: Int]
    ) -> Int {
        if let cached = memo[path] { return cached }
        if visited.contains(path) { return 0 }

        let edges = graph.outgoingEdges(for: path)
        if edges.isEmpty {
            memo[path] = 0
            return 0
        }

        var maxChildDepth = 0
        for edge in edges {
            if let targetPath = moduleToPath[edge.to] {
                let childDepth = computeMaxDepth(
                    for: targetPath,
                    in: graph,
                    moduleToPath: moduleToPath,
                    visited: visited + [path],
                    memo: &memo
                )
                maxChildDepth = max(maxChildDepth, childDepth)
            }
        }

        let depth = maxChildDepth + 1
        memo[path] = depth
        return depth
    }

    // MARK: - Inheritance Graph Signals

    private func findDeepHierarchies(in graph: InheritanceGraph, threshold: Int = 3) -> [Signal] {
        let deepTypes = graph.findDeepHierarchies(threshold: threshold)
        return deepTypes.map { typeName, depth in
            let node = graph.nodes.first { $0.name == typeName }
            let severity: Severity = depth >= 5 ? .error : .warning
            return Signal(
                name: "deep-hierarchy",
                severity: severity,
                message: "Type '\(typeName)' has inheritance depth of \(depth) - consider composition",
                file: node?.filePath
            )
        }
    }

    private func findWideProtocols(in graph: InheritanceGraph, threshold: Int = 5) -> [Signal] {
        var signals: [Signal] = []
        let protocols = graph.nodes.filter { $0.kind == .protocol }

        for proto in protocols {
            let conformers = graph.subtypes(of: proto.name)
            if conformers.count >= threshold {
                let severity: Severity = conformers.count >= 10 ? .error : .warning
                signals.append(Signal(
                    name: "wide-protocol",
                    severity: severity,
                    message: "Protocol '\(proto.name)' has \(conformers.count) conformers - high coupling",
                    file: proto.filePath
                ))
            }
        }
        return signals
    }

    // MARK: - Call Graph Signals

    private func findHotFunctions(in graph: CallGraph, threshold: Int = 5) -> [Signal] {
        let hotFns = graph.findHotFunctions(threshold: threshold)
        return hotFns.map { name, callCount in
            let node = graph.nodes.first { $0.name == name }
            let severity: Severity = callCount >= 10 ? .error : .warning
            return Signal(
                name: "hot-function",
                severity: severity,
                message: "Function '\(name)' is called \(callCount) times - potential bottleneck",
                file: node?.filePath
            )
        }
    }

    private func findUnusedFunctions(in graph: CallGraph) -> [Signal] {
        let unused = graph.findUnusedFunctions()
        let ignoredNames: Set<String> = [
            "main", "visit", "visitPost", "run", "hash", "encode", "decode"
        ]
        let ignoredPrefixes = ["init", "test", "setUp", "tearDown"]
        
        return unused.compactMap { fn in
            if ignoredNames.contains(fn.name) { return nil }
            if ignoredPrefixes.contains(where: { fn.name.hasPrefix($0) }) { return nil }
            return Signal(
                name: "unused-function",
                severity: .info,
                message: "Function '\(fn.name)' is never called internally",
                file: fn.filePath
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
