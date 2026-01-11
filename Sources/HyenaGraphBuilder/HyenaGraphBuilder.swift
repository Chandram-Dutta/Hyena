import Foundation
import HyenaIRStore

public struct HyenaGraphBuilder {
    public init() {}

    public func buildGraphs(from irStore: IRStore) throws -> GraphResult {
        let graph = buildFileDependencyGraph(from: irStore.fileImports)
        return GraphResult(fileDependencyGraph: graph)
    }

    private func buildFileDependencyGraph(from fileImports: [FileImports]) -> FileDependencyGraph {
        var nodes: [FileNode] = []
        var edges: [FileEdge] = []

        let moduleToFile = buildModuleToFileMap(from: fileImports)

        for file in fileImports {
            let node = FileNode(path: file.path, moduleName: extractModuleName(from: file.path))
            nodes.append(node)

            for importedModule in file.imports {
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
}

public struct GraphResult {
    public let fileDependencyGraph: FileDependencyGraph

    public init(fileDependencyGraph: FileDependencyGraph) {
        self.fileDependencyGraph = fileDependencyGraph
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

    public init(path: String, moduleName: String) {
        self.path = path
        self.moduleName = moduleName
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
