import Foundation
import HyenaGraphBuilder
import HyenaIRStore
import HyenaSignalEngine

public struct HyenaReporters {
    private let jsonExporter = JSONExporter()
    private let dotExporter = DOTExporter()
    private let mermaidExporter = MermaidExporter()
    
    public init() {}
    
    public func printHeader(path: String) {
        let box = Box(width: 60)
        print("")
        print(Console.styled(box.top(title: "HYENA"), .cyan))
        print(Console.styled(box.middle("Static Analysis Engine for Swift"), .cyan))
        print(Console.styled(box.bottom(), .cyan))
        print("")
        print(Console.dim("Target: ") + Console.highlight(path))
        print("")
    }
    
    public func printStage(_ number: Int, of total: Int, _ name: String) {
        let prefix = Console.dim("[\(number)/\(total)]")
        print("\(prefix) \(name)...")
    }
    
    public func printStageComplete(_ message: String) {
        print("    \(Console.success(Symbols.checkmark)) \(Console.dim(message))")
    }

    public func reportImports(_ fileImports: [FileImports], verbose: Bool = false) {
        guard verbose else { return }
        
        print("")
        print(Console.bold("File Imports"))
        print(Console.dim(String(repeating: "─", count: 40)))
        
        for file in fileImports {
            let fileName = Console.file(file.path)
            if file.imports.isEmpty {
                print("  \(fileName) \(Console.dim("\(Symbols.arrow) (none)"))")
            } else {
                let imports = file.moduleNames.map { Console.info($0) }.joined(separator: ", ")
                print("  \(fileName) \(Symbols.arrow) \(imports)")
            }
        }
        print("")
    }

    public func reportSignals(_ signals: SignalResult, fileCount: Int = 0, typeCount: Int = 0, functionCount: Int = 0) {
        print("")
        
        if signals.signals.isEmpty {
            printSuccessBox(fileCount: fileCount, typeCount: typeCount, functionCount: functionCount)
            return
        }
        
        printSignalsDetail(signals)
        printSummaryBox(fileCount: fileCount, typeCount: typeCount, functionCount: functionCount, signals: signals)
    }
    
    private func printSignalsDetail(_ signals: SignalResult) {
        print(Console.bold("Issues Found"))
        print(Console.dim(String(repeating: "─", count: 60)))
        print("")

        let grouped = Dictionary(grouping: signals.signals) { $0.name }
        let sortedGroups = grouped.sorted { lhs, rhs in
            let lhsSeverity = maxSeverity(lhs.value)
            let rhsSeverity = maxSeverity(rhs.value)
            if lhsSeverity != rhsSeverity {
                return severityOrder(lhsSeverity) < severityOrder(rhsSeverity)
            }
            return lhs.key < rhs.key
        }

        for (name, signalGroup) in sortedGroups {
            let countStr = Console.dim("(\(signalGroup.count))")
            let severity = maxSeverity(signalGroup)
            let header = severityStyled(name, severity)
            print("\(header) \(countStr)")
            
            for signal in signalGroup.prefix(5) {
                let icon = severityIcon(signal.severity)
                let styledIcon = severityStyledIcon(icon, signal.severity)
                let filePart: String
                if let file = signal.file {
                    filePart = " \(Console.dim("in")) \(Console.file(file))"
                } else {
                    filePart = ""
                }
                print("  \(styledIcon) \(signal.message)\(filePart)")
            }
            
            if signalGroup.count > 5 {
                print("  \(Console.dim("... and \(signalGroup.count - 5) more"))")
            }
            print("")
        }
    }
    
    private func printSuccessBox(fileCount: Int, typeCount: Int, functionCount: Int) {
        let box = Box(width: 50)
        print(Console.success(box.top(title: "SUCCESS")))
        print(Console.success(box.middle("")))
        print(Console.success(box.middle("  \(Symbols.checkmark) No issues detected!")))
        print(Console.success(box.middle("")))
        print(Console.success(box.middle("  Files:     \(fileCount)")))
        print(Console.success(box.middle("  Types:     \(typeCount)")))
        print(Console.success(box.middle("  Functions: \(functionCount)")))
        print(Console.success(box.middle("")))
        print(Console.success(box.bottom()))
        print("")
    }
    
    private func printSummaryBox(fileCount: Int, typeCount: Int, functionCount: Int, signals: SignalResult) {
        let errorCount = signals.signals(withSeverity: .error).count
        let warningCount = signals.signals(withSeverity: .warning).count
        let infoCount = signals.signals(withSeverity: .info).count
        
        let box = Box(width: 50)
        
        let borderColor: Console.Color = errorCount > 0 ? .red : (warningCount > 0 ? .yellow : .green)
        
        func coloredLine(_ line: String) -> String {
            Console.styled(box.middle(line), borderColor)
        }
        
        print(Console.styled(box.top(title: "SUMMARY"), borderColor))
        print(coloredLine(""))
        print(coloredLine("Files analyzed:     \(fileCount)"))
        print(coloredLine("Types found:        \(typeCount)"))
        print(coloredLine("Functions found:    \(functionCount)"))
        print(coloredLine(""))
        print(coloredLine("\(Symbols.cross) Errors:   \(errorCount)"))
        print(coloredLine("\(Symbols.warning) Warnings: \(warningCount)"))
        print(coloredLine("\(Symbols.info) Info:     \(infoCount)"))
        print(coloredLine(""))
        print(Console.styled(box.bottom(), borderColor))
        print("")
    }
    
    private func maxSeverity(_ signals: [Signal]) -> Severity {
        if signals.contains(where: { $0.severity == .error }) { return .error }
        if signals.contains(where: { $0.severity == .warning }) { return .warning }
        return .info
    }
    
    private func severityOrder(_ severity: Severity) -> Int {
        switch severity {
        case .error: return 0
        case .warning: return 1
        case .info: return 2
        }
    }
    
    private func severityStyled(_ text: String, _ severity: Severity) -> String {
        switch severity {
        case .error: return Console.error(text)
        case .warning: return Console.warning(text)
        case .info: return Console.info(text)
        }
    }
    
    private func severityStyledIcon(_ icon: String, _ severity: Severity) -> String {
        switch severity {
        case .error: return Console.error(icon)
        case .warning: return Console.warning(icon)
        case .info: return Console.info(icon)
        }
    }

    private func severityIcon(_ severity: Severity) -> String {
        switch severity {
        case .info: return Symbols.info
        case .warning: return Symbols.warning
        case .error: return Symbols.cross
        }
    }
    
    public func printCompletion(duration: TimeInterval) {
        let formatted = String(format: "%.2fs", duration)
        print(Console.success(Symbols.checkmark) + " " + Console.bold("Analysis complete") + " " + Console.dim("in \(formatted)"))
        print("")
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
