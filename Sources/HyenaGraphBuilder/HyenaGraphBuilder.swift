import Foundation
import HyenaIRStore

public struct HyenaGraphBuilder {
    public init() {}

    public func buildGraphs(from irStore: IRStore) throws -> GraphResult {
        return GraphResult(graphs: [])
    }
}

public struct GraphResult {
    public let graphs: [Graph]

    public init(graphs: [Graph]) {
        self.graphs = graphs
    }
}

public struct Graph {
    public let nodes: [Node]
    public let edges: [Edge]

    public init(nodes: [Node], edges: [Edge]) {
        self.nodes = nodes
        self.edges = edges
    }
}

public struct Node {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public struct Edge {
    public let from: String
    public let to: String

    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
}
