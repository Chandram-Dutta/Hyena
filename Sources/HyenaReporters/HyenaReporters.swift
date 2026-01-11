import Foundation
import HyenaGraphBuilder
import HyenaIRStore
import HyenaSignalEngine

public struct HyenaReporters {
    private let jsonExporter = JSONExporter()
    private let dotExporter = DOTExporter()
    private let mermaidExporter = MermaidExporter()
    
    public init() {}

    public func reportImports(_ fileImports: [FileImports]) {
        print("\n--- File Imports ---\n")
        for file in fileImports {
            let fileName = (file.path as NSString).lastPathComponent
            if file.imports.isEmpty {
                print("\(fileName) → (none)")
            } else {
                print("\(fileName) → \(file.moduleNames.joined(separator: ", "))")
            }
        }
        print("")
    }

    public func reportSignals(_ signals: SignalResult) {
        print("--- Signals ---\n")

        if signals.signals.isEmpty {
            print("No signals detected.\n")
            return
        }

        let grouped = Dictionary(grouping: signals.signals) { $0.name }

        for (name, signalGroup) in grouped.sorted(by: { $0.key < $1.key }) {
            print("[\(name)] (\(signalGroup.count) issue\(signalGroup.count == 1 ? "" : "s"))")
            for signal in signalGroup {
                let icon = severityIcon(signal.severity)
                let filePart = signal.file.map { " - \(($0 as NSString).lastPathComponent)" } ?? ""
                print("  \(icon) \(signal.message)\(filePart)")
            }
            print("")
        }
    }

    private func severityIcon(_ severity: Severity) -> String {
        switch severity {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    public func export(
        ir: IRStore,
        graphs: GraphResult,
        signals: SignalResult,
        format: ExportFormat
    ) -> ExportResult {
        switch format {
        case .json:
            return jsonExporter.export(ir: ir, graphs: graphs, signals: signals)
        case .dot:
            return dotExporter.export(ir: ir, graphs: graphs, signals: signals)
        case .mermaid:
            return mermaidExporter.export(ir: ir, graphs: graphs, signals: signals)
        }
    }
    
    public func exportFileDependencyGraph(_ graph: FileDependencyGraph, format: ExportFormat) -> String {
        switch format {
        case .json:
            return "{}"
        case .dot:
            return dotExporter.exportFileDependencyOnly(graph)
        case .mermaid:
            return mermaidExporter.exportFileDependencyOnly(graph)
        }
    }
    
    public func exportInheritanceGraph(_ graph: InheritanceGraph, format: ExportFormat) -> String {
        switch format {
        case .json:
            return "{}"
        case .dot:
            return dotExporter.exportInheritanceOnly(graph)
        case .mermaid:
            return mermaidExporter.exportInheritanceOnly(graph)
        }
    }
    
    public func exportCallGraph(_ graph: CallGraph, format: ExportFormat) -> String {
        switch format {
        case .json:
            return "{}"
        case .dot:
            return dotExporter.exportCallGraphOnly(graph)
        case .mermaid:
            return mermaidExporter.exportCallGraphOnly(graph)
        }
    }
}
