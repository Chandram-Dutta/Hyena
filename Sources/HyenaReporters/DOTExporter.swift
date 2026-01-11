import Foundation
import HyenaGraphBuilder
import HyenaIRStore
import HyenaSignalEngine

public struct DOTExporter: GraphExporter {
    public init() {}
    
    public func export(
        ir: IRStore,
        graphs: GraphResult,
        signals: SignalResult
    ) -> ExportResult {
        var lines: [String] = []
        lines.append("digraph Hyena {")
        lines.append("  rankdir=LR;")
        lines.append("  node [shape=box, fontname=\"Helvetica\"];")
        lines.append("")
        
        lines.append(exportFileDependencyGraph(graphs.fileDependencyGraph))
        lines.append(exportInheritanceGraph(graphs.inheritanceGraph))
        lines.append(exportCallGraph(graphs.callGraph))
        
        lines.append("}")
        
        return ExportResult(content: lines.joined(separator: "\n"), format: .dot)
    }
    
    public func exportFileDependencyOnly(_ graph: FileDependencyGraph) -> String {
        var lines: [String] = []
        lines.append("digraph FileDependencies {")
        lines.append("  rankdir=LR;")
        lines.append("  node [shape=box, style=filled, fillcolor=lightblue];")
        lines.append("")
        
        for node in graph.nodes {
            let name = sanitize(node.moduleName)
            lines.append("  \(name);")
        }
        lines.append("")
        
        for edge in graph.edges {
            let from = sanitize(((edge.from as NSString).lastPathComponent as NSString).deletingPathExtension)
            let to = sanitize(edge.to)
            lines.append("  \(from) -> \(to);")
        }
        
        lines.append("}")
        return lines.joined(separator: "\n")
    }
    
    public func exportInheritanceOnly(_ graph: InheritanceGraph) -> String {
        var lines: [String] = []
        lines.append("digraph Inheritance {")
        lines.append("  rankdir=BT;")
        lines.append("  node [shape=box];")
        lines.append("")
        
        for node in graph.nodes {
            let name = sanitize(node.name)
            let color = colorForKind(node.kind)
            lines.append("  \(name) [style=filled, fillcolor=\(color)];")
        }
        lines.append("")
        
        for edge in graph.edges {
            let from = sanitize(edge.from)
            let to = sanitize(edge.to)
            let style = edge.isInternal ? "solid" : "dashed"
            lines.append("  \(from) -> \(to) [style=\(style)];")
        }
        
        lines.append("}")
        return lines.joined(separator: "\n")
    }
    
    public func exportCallGraphOnly(_ graph: CallGraph) -> String {
        var lines: [String] = []
        lines.append("digraph CallGraph {")
        lines.append("  rankdir=LR;")
        lines.append("  node [shape=ellipse, style=filled, fillcolor=lightyellow];")
        lines.append("")
        
        for node in graph.nodes {
            let name = sanitize(node.name)
            lines.append("  \(name);")
        }
        lines.append("")
        
        for edge in graph.edges where edge.caller != nil {
            let caller = sanitize(edge.caller!)
            let callee = sanitize(edge.callee)
            let style = edge.isInternal ? "solid" : "dashed"
            lines.append("  \(caller) -> \(callee) [style=\(style)];")
        }
        
        lines.append("}")
        return lines.joined(separator: "\n")
    }
    
    private func exportFileDependencyGraph(_ graph: FileDependencyGraph) -> String {
        var lines: [String] = []
        lines.append("  subgraph cluster_files {")
        lines.append("    label=\"File Dependencies\";")
        lines.append("    style=filled; fillcolor=lightgray;")
        
        for node in graph.nodes {
            let name = sanitize("file_" + node.moduleName)
            lines.append("    \(name) [label=\"\(node.moduleName)\", fillcolor=lightblue, style=filled];")
        }
        
        for edge in graph.edges {
            let from = sanitize("file_" + ((edge.from as NSString).lastPathComponent as NSString).deletingPathExtension)
            let to = sanitize("file_" + edge.to)
            lines.append("    \(from) -> \(to);")
        }
        
        lines.append("  }")
        return lines.joined(separator: "\n")
    }
    
    private func exportInheritanceGraph(_ graph: InheritanceGraph) -> String {
        var lines: [String] = []
        lines.append("  subgraph cluster_types {")
        lines.append("    label=\"Type Inheritance\";")
        lines.append("    style=filled; fillcolor=mistyrose;")
        
        for node in graph.nodes {
            let name = sanitize("type_" + node.name)
            let color = colorForKind(node.kind)
            lines.append("    \(name) [label=\"\(node.name)\", fillcolor=\(color), style=filled];")
        }
        
        for edge in graph.edges {
            let from = sanitize("type_" + edge.from)
            let to = sanitize("type_" + edge.to)
            lines.append("    \(from) -> \(to);")
        }
        
        lines.append("  }")
        return lines.joined(separator: "\n")
    }
    
    private func exportCallGraph(_ graph: CallGraph) -> String {
        var lines: [String] = []
        lines.append("  subgraph cluster_calls {")
        lines.append("    label=\"Call Graph\";")
        lines.append("    style=filled; fillcolor=honeydew;")
        
        for node in graph.nodes {
            let name = sanitize("fn_" + node.name)
            lines.append("    \(name) [label=\"\(node.name)\", shape=ellipse, fillcolor=lightyellow, style=filled];")
        }
        
        for edge in graph.edges where edge.caller != nil {
            let caller = sanitize("fn_" + edge.caller!)
            let callee = sanitize("fn_" + edge.callee)
            lines.append("    \(caller) -> \(callee);")
        }
        
        lines.append("  }")
        return lines.joined(separator: "\n")
    }
    
    private func colorForKind(_ kind: TypeDeclKind) -> String {
        switch kind {
        case .protocol: return "lightgreen"
        case .class: return "lightsalmon"
        case .struct: return "lightblue"
        case .enum: return "plum"
        case .actor: return "khaki"
        }
    }
    
    private func sanitize(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cleaned.isEmpty ? "unknown" : cleaned
    }
}
