import Foundation
import HyenaGraphBuilder
import HyenaIRStore
import HyenaSignalEngine

public struct JSONExporter: GraphExporter {
    public init() {}
    
    public func export(
        ir: IRStore,
        graphs: GraphResult,
        signals: SignalResult
    ) -> ExportResult {
        var root: [String: Any] = [:]
        
        root["files"] = exportFileImports(ir.fileImports)
        root["types"] = exportTypes(ir.typeDeclarations)
        root["functions"] = exportFunctions(ir.functionDeclarations)
        root["graphs"] = exportGraphs(graphs)
        root["signals"] = exportSignals(signals)
        root["summary"] = exportSummary(ir: ir, signals: signals)
        
        let jsonData = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
        let content = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        return ExportResult(content: content, format: .json)
    }
    
    private func exportFileImports(_ fileImports: [FileImports]) -> [[String: Any]] {
        fileImports.map { file in
            [
                "path": file.path,
                "fileName": (file.path as NSString).lastPathComponent,
                "imports": file.imports.map { imp in
                    [
                        "moduleName": imp.moduleName,
                        "isTestable": imp.isTestable,
                        "line": imp.line
                    ] as [String: Any]
                }
            ] as [String: Any]
        }
    }
    
    private func exportTypes(_ types: [TypeDeclaration]) -> [[String: Any]] {
        types.map { type in
            [
                "name": type.name,
                "kind": type.kind.rawValue,
                "filePath": type.filePath,
                "accessibility": type.accessibility.rawValue,
                "inheritedTypes": type.inheritedTypes,
                "line": type.line,
                "endLine": type.endLine,
                "attributes": type.attributes,
                "genericParameters": type.genericParameters
            ] as [String: Any]
        }
    }
    
    private func exportFunctions(_ functions: [FunctionDeclaration]) -> [[String: Any]] {
        functions.map { fn in
            [
                "name": fn.name,
                "signature": fn.signature,
                "filePath": fn.filePath,
                "accessibility": fn.accessibility.rawValue,
                "isStatic": fn.isStatic,
                "isAsync": fn.isAsync,
                "isThrows": fn.isThrows,
                "isMutating": fn.isMutating,
                "line": fn.line,
                "endLine": fn.endLine,
                "containingType": fn.containingType as Any,
                "parameters": fn.parameters.map { param in
                    [
                        "label": param.label as Any,
                        "name": param.name,
                        "type": param.type
                    ] as [String: Any]
                },
                "returnType": fn.returnType as Any
            ] as [String: Any]
        }
    }
    
    private func exportGraphs(_ graphs: GraphResult) -> [String: Any] {
        [
            "fileDependency": exportFileDependencyGraph(graphs.fileDependencyGraph),
            "inheritance": exportInheritanceGraph(graphs.inheritanceGraph),
            "callGraph": exportCallGraph(graphs.callGraph)
        ]
    }
    
    private func exportFileDependencyGraph(_ graph: FileDependencyGraph) -> [String: Any] {
        [
            "nodes": graph.nodes.map { node in
                [
                    "path": node.path,
                    "moduleName": node.moduleName
                ] as [String: Any]
            },
            "edges": graph.edges.map { edge in
                [
                    "from": edge.from,
                    "to": edge.to,
                    "resolvedPath": edge.resolvedPath as Any
                ] as [String: Any]
            }
        ]
    }
    
    private func exportInheritanceGraph(_ graph: InheritanceGraph) -> [String: Any] {
        [
            "nodes": graph.nodes.map { node in
                [
                    "name": node.name,
                    "kind": node.kind.rawValue,
                    "filePath": node.filePath,
                    "line": node.line
                ] as [String: Any]
            },
            "edges": graph.edges.map { edge in
                [
                    "from": edge.from,
                    "to": edge.to,
                    "isInternal": edge.isInternal
                ] as [String: Any]
            }
        ]
    }
    
    private func exportCallGraph(_ graph: CallGraph) -> [String: Any] {
        [
            "nodes": graph.nodes.map { node in
                [
                    "name": node.name,
                    "signature": node.signature,
                    "filePath": node.filePath,
                    "line": node.line,
                    "containingType": node.containingType as Any
                ] as [String: Any]
            },
            "edges": graph.edges.map { edge in
                [
                    "caller": edge.caller as Any,
                    "callee": edge.callee,
                    "filePath": edge.filePath,
                    "line": edge.line,
                    "isInternal": edge.isInternal
                ] as [String: Any]
            }
        ]
    }
    
    private func exportSignals(_ result: SignalResult) -> [[String: Any]] {
        result.signals.map { signal in
            [
                "name": signal.name,
                "severity": signal.severity.rawValue,
                "message": signal.message,
                "file": signal.file as Any
            ] as [String: Any]
        }
    }
    
    private func exportSummary(ir: IRStore, signals: SignalResult) -> [String: Any] {
        let errorCount = signals.signals(withSeverity: .error).count
        let warningCount = signals.signals(withSeverity: .warning).count
        let infoCount = signals.signals(withSeverity: .info).count
        
        return [
            "fileCount": ir.fileImports.count,
            "typeCount": ir.typeDeclarations.count,
            "functionCount": ir.functionDeclarations.count,
            "callSiteCount": ir.callSites.count,
            "signalCount": [
                "total": signals.signals.count,
                "errors": errorCount,
                "warnings": warningCount,
                "info": infoCount
            ]
        ]
    }
}
