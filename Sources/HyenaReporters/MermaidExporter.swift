import Foundation
import HyenaGraphBuilder
import HyenaIRStore
import HyenaSignalEngine

public struct MermaidExporter: GraphExporter {
    public init() {}
    
    public func export(
        ir: IRStore,
        graphs: GraphResult,
        signals: SignalResult
    ) -> ExportResult {
        var sections: [String] = []
        
        sections.append(exportFileDependencyGraph(graphs.fileDependencyGraph))
        sections.append(exportInheritanceGraph(graphs.inheritanceGraph))
        sections.append(exportCallGraph(graphs.callGraph))
        
        return ExportResult(content: sections.joined(separator: "\n\n"), format: .mermaid)
    }
    
    public func exportFileDependencyOnly(_ graph: FileDependencyGraph) -> String {
        var lines: [String] = []
        lines.append("```mermaid")
        lines.append("flowchart LR")
        lines.append("  subgraph Files")
        
        for node in graph.nodes {
            let id = sanitize(node.moduleName)
            lines.append("    \(id)[\(node.moduleName)]")
        }
        
        for edge in graph.edges {
            let from = sanitize(((edge.from as NSString).lastPathComponent as NSString).deletingPathExtension)
            let to = sanitize(edge.to)
            lines.append("    \(from) --> \(to)")
        }
        
        lines.append("  end")
        lines.append("```")
        return lines.joined(separator: "\n")
    }
    
    public func exportInheritanceOnly(_ graph: InheritanceGraph) -> String {
        var lines: [String] = []
        lines.append("```mermaid")
        lines.append("flowchart BT")
        lines.append("  subgraph Types")
        
        for node in graph.nodes {
            let id = sanitize(node.name)
            let shape = shapeForKind(node.kind, name: node.name)
            lines.append("    \(shape)")
        }
        
        for edge in graph.edges {
            let from = sanitize(edge.from)
            let to = sanitize(edge.to)
            let arrow = edge.isInternal ? "-->" : "-.->"
            lines.append("    \(from) \(arrow) \(to)")
        }
        
        lines.append("  end")
        lines.append("```")
        return lines.joined(separator: "\n")
    }
    
    public func exportCallGraphOnly(_ graph: CallGraph) -> String {
        var lines: [String] = []
        lines.append("```mermaid")
        lines.append("flowchart LR")
        lines.append("  subgraph Functions")
        
        for node in graph.nodes {
            let id = sanitize(node.name)
            lines.append("    \(id)((\(node.name)))")
        }
        
        for edge in graph.edges where edge.caller != nil {
            let caller = sanitize(edge.caller!)
            let callee = sanitize(edge.callee)
            let arrow = edge.isInternal ? "-->" : "-.->"
            lines.append("    \(caller) \(arrow) \(callee)")
        }
        
        lines.append("  end")
        lines.append("```")
        return lines.joined(separator: "\n")
    }
    
    private func exportFileDependencyGraph(_ graph: FileDependencyGraph) -> String {
        var lines: [String] = []
        lines.append("## File Dependencies")
        lines.append("")
        lines.append("```mermaid")
        lines.append("flowchart LR")
        
        for node in graph.nodes {
            let id = sanitize("f_" + node.moduleName)
            lines.append("  \(id)[\(node.moduleName)]")
        }
        
        for edge in graph.edges {
            let from = sanitize("f_" + ((edge.from as NSString).lastPathComponent as NSString).deletingPathExtension)
            let to = sanitize("f_" + edge.to)
            lines.append("  \(from) --> \(to)")
        }
        
        lines.append("```")
        return lines.joined(separator: "\n")
    }
    
    private func exportInheritanceGraph(_ graph: InheritanceGraph) -> String {
        var lines: [String] = []
        lines.append("## Type Inheritance")
        lines.append("")
        lines.append("```mermaid")
        lines.append("flowchart BT")
        
        for node in graph.nodes {
            let id = sanitize("t_" + node.name)
            let shape = shapeForKind(node.kind, name: node.name, prefix: "t_")
            lines.append("  \(shape)")
        }
        
        for edge in graph.edges {
            let from = sanitize("t_" + edge.from)
            let to = sanitize("t_" + edge.to)
            let arrow = edge.isInternal ? "-->" : "-.->"
            lines.append("  \(from) \(arrow) \(to)")
        }
        
        lines.append("```")
        return lines.joined(separator: "\n")
    }
    
    private func exportCallGraph(_ graph: CallGraph) -> String {
        var lines: [String] = []
        lines.append("## Call Graph")
        lines.append("")
        lines.append("```mermaid")
        lines.append("flowchart LR")
        
        for node in graph.nodes {
            let id = sanitize("c_" + node.name)
            lines.append("  \(id)((\(node.name)))")
        }
        
        for edge in graph.edges where edge.caller != nil {
            let caller = sanitize("c_" + edge.caller!)
            let callee = sanitize("c_" + edge.callee)
            let arrow = edge.isInternal ? "-->" : "-.->"
            lines.append("  \(caller) \(arrow) \(callee)")
        }
        
        lines.append("```")
        return lines.joined(separator: "\n")
    }
    
    private func shapeForKind(_ kind: TypeDeclKind, name: String, prefix: String = "") -> String {
        let id = sanitize(prefix + name)
        switch kind {
        case .protocol: return "\(id){{\(name)}}"
        case .class: return "\(id)[[\(name)]]"
        case .struct: return "\(id)[\(name)]"
        case .enum: return "\(id)[/\(name)/]"
        case .actor: return "\(id)[(\(name))]"
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
