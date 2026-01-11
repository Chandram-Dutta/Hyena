import Foundation
import HyenaIRStore

public struct HyenaGraphBuilder {
    public init() {}

    public func buildGraphs(from irStore: IRStore) throws -> GraphResult {
        let fileDependencyGraph = buildFileDependencyGraph(from: irStore.fileImports)
        let inheritanceGraph = buildInheritanceGraph(from: irStore.typeDeclarations)
        let callGraph = buildCallGraph(
            functions: irStore.functionDeclarations,
            callSites: irStore.callSites
        )
        return GraphResult(
            fileDependencyGraph: fileDependencyGraph,
            inheritanceGraph: inheritanceGraph,
            callGraph: callGraph
        )
    }

    private func buildFileDependencyGraph(from fileImports: [FileImports]) -> FileDependencyGraph {
        var nodes: [FileNode] = []
        var edges: [FileEdge] = []

        let moduleToFile = buildModuleToFileMap(from: fileImports)

        for file in fileImports {
            let node = FileNode(
                path: file.path,
                moduleName: extractModuleName(from: file.path),
                isEntryPoint: file.isEntryPoint
            )
            nodes.append(node)

            for importedModule in file.moduleNames {
                let edge = FileEdge(
                    from: file.path,
                    to: importedModule,
                    resolvedPath: moduleToFile[importedModule]
                )
                edges.append(edge)
            }
        }

        return FileDependencyGraph(nodes: nodes, edges: edges)
    }

    private func buildModuleToFileMap(from fileImports: [FileImports]) -> [String: String] {
        var map: [String: String] = [:]
        for file in fileImports {
            let moduleName = extractModuleName(from: file.path)
            map[moduleName] = file.path
        }
        return map
    }

    private func extractModuleName(from path: String) -> String {
        let fileName = (path as NSString).lastPathComponent
        return (fileName as NSString).deletingPathExtension
    }

    // MARK: - Inheritance Graph

    private func buildInheritanceGraph(from typeDeclarations: [TypeDeclaration]) -> InheritanceGraph {
        var nodes: [TypeNode] = []
        var edges: [InheritanceEdge] = []

        let knownTypes = Set(typeDeclarations.map { $0.name })

        for type in typeDeclarations {
            nodes.append(TypeNode(
                name: type.name,
                kind: type.kind,
                filePath: type.filePath,
                line: type.line
            ))

            for inherited in type.inheritedTypes {
                let isInternal = knownTypes.contains(inherited)
                edges.append(InheritanceEdge(
                    from: type.name,
                    to: inherited,
                    isInternal: isInternal
                ))
            }
        }

        return InheritanceGraph(nodes: nodes, edges: edges)
    }

    // MARK: - Call Graph

    private func buildCallGraph(
        functions: [FunctionDeclaration],
        callSites: [CallSite]
    ) -> CallGraph {
        var nodes: [FunctionNode] = []
        var edges: [CallEdge] = []

        let functionNames = Set(functions.map { $0.name })

        for fn in functions {
            nodes.append(FunctionNode(
                name: fn.name,
                signature: fn.signature,
                filePath: fn.filePath,
                line: fn.line,
                containingType: fn.containingType,
                accessibility: FunctionAccessibility(rawValue: fn.accessibility.rawValue) ?? .internal
            ))
        }

        for call in callSites {
            let isInternal = functionNames.contains(call.calledName)
            edges.append(CallEdge(
                caller: call.containingFunction,
                callee: call.calledName,
                filePath: call.filePath,
                line: call.line,
                isInternal: isInternal
            ))
        }

        return CallGraph(nodes: nodes, edges: edges)
    }
}

public struct GraphResult {
    public let fileDependencyGraph: FileDependencyGraph
    public let inheritanceGraph: InheritanceGraph
    public let callGraph: CallGraph

    public init(
        fileDependencyGraph: FileDependencyGraph,
        inheritanceGraph: InheritanceGraph,
        callGraph: CallGraph
    ) {
        self.fileDependencyGraph = fileDependencyGraph
        self.inheritanceGraph = inheritanceGraph
        self.callGraph = callGraph
    }
}

public struct FileDependencyGraph {
    public let nodes: [FileNode]
    public let edges: [FileEdge]

    public init(nodes: [FileNode], edges: [FileEdge]) {
        self.nodes = nodes
        self.edges = edges
    }

    public var allFilePaths: Set<String> {
        Set(nodes.map { $0.path })
    }

    public var allImportedModules: Set<String> {
        Set(edges.map { $0.to })
    }

    public func incomingEdges(for path: String) -> [FileEdge] {
        let moduleName = (((path as NSString).lastPathComponent) as NSString).deletingPathExtension
        return edges.filter { $0.to == moduleName }
    }

    public func outgoingEdges(for path: String) -> [FileEdge] {
        edges.filter { $0.from == path }
    }

    public func findCycles() -> [[String]] {
        var visited: Set<String> = []
        var recursionStack: Set<String> = []
        var cycles: [[String]] = []
        var currentPath: [String] = []

        let moduleToPath = Dictionary(uniqueKeysWithValues: nodes.map { ($0.moduleName, $0.path) })

        func dfs(_ path: String) {
            visited.insert(path)
            recursionStack.insert(path)
            currentPath.append(path)

            for edge in outgoingEdges(for: path) {
                if let targetPath = moduleToPath[edge.to] {
                    if !visited.contains(targetPath) {
                        dfs(targetPath)
                    } else if recursionStack.contains(targetPath) {
                        if let cycleStart = currentPath.firstIndex(of: targetPath) {
                            let cycle = Array(currentPath[cycleStart...]) + [targetPath]
                            cycles.append(cycle)
                        }
                    }
                }
            }

            currentPath.removeLast()
            recursionStack.remove(path)
        }

        for node in nodes {
            if !visited.contains(node.path) {
                dfs(node.path)
            }
        }

        return cycles
    }
}

public struct FileNode {
    public let path: String
    public let moduleName: String
    public let isEntryPoint: Bool

    public init(path: String, moduleName: String, isEntryPoint: Bool = false) {
        self.path = path
        self.moduleName = moduleName
        self.isEntryPoint = isEntryPoint
    }
}

public struct FileEdge {
    public let from: String
    public let to: String
    public let resolvedPath: String?

    public init(from: String, to: String, resolvedPath: String? = nil) {
        self.from = from
        self.to = to
        self.resolvedPath = resolvedPath
    }
}

// MARK: - Inheritance Graph

public struct InheritanceGraph {
    public let nodes: [TypeNode]
    public let edges: [InheritanceEdge]

    public init(nodes: [TypeNode], edges: [InheritanceEdge]) {
        self.nodes = nodes
        self.edges = edges
    }

    public var allTypeNames: Set<String> {
        Set(nodes.map { $0.name })
    }

    public func subtypes(of typeName: String) -> [TypeNode] {
        let subtypeNames = edges.filter { $0.to == typeName }.map { $0.from }
        return nodes.filter { subtypeNames.contains($0.name) }
    }

    public func supertypes(of typeName: String) -> [String] {
        edges.filter { $0.from == typeName }.map { $0.to }
    }

    public func findDeepHierarchies(threshold: Int = 3) -> [String: Int] {
        var depths: [String: Int] = [:]

        func computeDepth(_ typeName: String, visited: Set<String>) -> Int {
            if visited.contains(typeName) { return 0 }
            if let cached = depths[typeName] { return cached }

            let parents = supertypes(of: typeName).filter { allTypeNames.contains($0) }
            if parents.isEmpty {
                depths[typeName] = 0
                return 0
            }

            let maxParentDepth = parents.map { computeDepth($0, visited: visited.union([typeName])) }.max() ?? 0
            let depth = maxParentDepth + 1
            depths[typeName] = depth
            return depth
        }

        for node in nodes {
            _ = computeDepth(node.name, visited: [])
        }

        return depths.filter { $0.value >= threshold }
    }
}

public struct TypeNode {
    public let name: String
    public let kind: TypeDeclKind
    public let filePath: String
    public let line: Int

    public init(name: String, kind: TypeDeclKind, filePath: String, line: Int) {
        self.name = name
        self.kind = kind
        self.filePath = filePath
        self.line = line
    }
}

public struct InheritanceEdge {
    public let from: String
    public let to: String
    public let isInternal: Bool

    public init(from: String, to: String, isInternal: Bool) {
        self.from = from
        self.to = to
        self.isInternal = isInternal
    }
}

// MARK: - Call Graph

public struct CallGraph {
    public let nodes: [FunctionNode]
    public let edges: [CallEdge]

    public init(nodes: [FunctionNode], edges: [CallEdge]) {
        self.nodes = nodes
        self.edges = edges
    }

    public var allFunctionNames: Set<String> {
        Set(nodes.map { $0.name })
    }

    public func callsFrom(_ functionName: String) -> [CallEdge] {
        edges.filter { $0.caller == functionName }
    }

    public func callsTo(_ functionName: String) -> [CallEdge] {
        edges.filter { $0.callee == functionName }
    }

    public func findHotFunctions(threshold: Int = 5) -> [(name: String, callCount: Int)] {
        var callCounts: [String: Int] = [:]
        for edge in edges where edge.isInternal {
            callCounts[edge.callee, default: 0] += 1
        }
        return callCounts
            .filter { $0.value >= threshold }
            .map { (name: $0.key, callCount: $0.value) }
            .sorted { $0.callCount > $1.callCount }
    }

    public func findUnusedFunctions() -> [FunctionNode] {
        let calledFunctions = Set(edges.filter { $0.isInternal }.map { $0.callee })
        return nodes.filter { !calledFunctions.contains($0.name) }
    }
}

public struct FunctionNode {
    public let name: String
    public let signature: String
    public let filePath: String
    public let line: Int
    public let containingType: String?
    public let accessibility: FunctionAccessibility

    public init(
        name: String,
        signature: String,
        filePath: String,
        line: Int,
        containingType: String?,
        accessibility: FunctionAccessibility = .internal
    ) {
        self.name = name
        self.signature = signature
        self.filePath = filePath
        self.line = line
        self.containingType = containingType
        self.accessibility = accessibility
    }
}

public enum FunctionAccessibility: String {
    case `public`
    case `internal`
    case `private`
    case `fileprivate`
    case `open`
    case package
}

public struct CallEdge {
    public let caller: String?
    public let callee: String
    public let filePath: String
    public let line: Int
    public let isInternal: Bool

    public init(caller: String?, callee: String, filePath: String, line: Int, isInternal: Bool) {
        self.caller = caller
        self.callee = callee
        self.filePath = filePath
        self.line = line
        self.isInternal = isInternal
    }
}
