import Foundation
import HyenaGraphBuilder
import HyenaIRStore
import HyenaParser
import HyenaReporters
import HyenaSignalEngine

public struct HyenaEngine {
    private let parser: HyenaParser
    private let irStore: HyenaIRStore
    private let graphBuilder: HyenaGraphBuilder
    private let signalEngine: HyenaSignalEngine
    private let reporters: HyenaReporters

    public init() {
        self.parser = HyenaParser()
        self.irStore = HyenaIRStore()
        self.graphBuilder = HyenaGraphBuilder()
        self.signalEngine = HyenaSignalEngine()
        self.reporters = HyenaReporters()
    }

    public func scan(path: String, exportFormat: ExportFormat? = nil, outputPath: String? = nil) throws {
        print("Starting Hyena analysis for: \(path)")

        let parsedFiles = try runIngestion(at: path)
        let ir = buildIR(from: parsedFiles)
        let graphs = try buildGraphs(from: ir)
        let signals = try runSignals(on: graphs)
        
        if let format = exportFormat {
            try export(ir: ir, graphs: graphs, signals: signals, format: format, outputPath: outputPath)
        } else {
            report(ir: ir, signals: signals)
        }

        print("Analysis complete")
    }
    
    private func export(
        ir: IRStore,
        graphs: GraphResult,
        signals: SignalResult,
        format: ExportFormat,
        outputPath: String?
    ) throws {
        print("Stage 5: Exporting as \(format.rawValue)...")
        let result = reporters.export(ir: ir, graphs: graphs, signals: signals, format: format)
        
        if let path = outputPath {
            try result.write(to: path)
            print("Exported to: \(path)")
        } else {
            print(result.content)
        }
    }

    private func runIngestion(at path: String) throws -> [ParsedFile] {
        print("Stage 1: Running ingestion...")
        return try parser.parse(at: path)
    }

    private func buildIR(from parsedFiles: [ParsedFile]) -> IRStore {
        print("Stage 2: Building IR...")

        let fileImports = parsedFiles.map { file in
            FileImports(
                path: file.path,
                imports: file.imports.map { imp in
                    ImportInfo(moduleName: imp.moduleName, isTestable: imp.isTestable, line: imp.line)
                },
                isEntryPoint: file.hasMainAttribute
            )
        }

        var typeDeclarations: [TypeDeclaration] = []
        var functionDeclarations: [FunctionDeclaration] = []
        var callSites: [CallSite] = []

        for file in parsedFiles {
            for (index, type) in file.types.enumerated() {
                let id = TypeID("\(file.path):\(type.name):\(index)")
                typeDeclarations.append(TypeDeclaration(
                    id: id,
                    name: type.name,
                    kind: TypeDeclKind(rawValue: type.kind.rawValue) ?? .struct,
                    filePath: file.path,
                    inheritedTypes: type.inheritedTypes,
                    accessibility: Accessibility(rawValue: type.accessibility.rawValue) ?? .internal,
                    line: type.line,
                    endLine: type.endLine,
                    attributes: type.attributes,
                    genericParameters: type.genericParameters
                ))
            }

            for (index, fn) in file.functions.enumerated() {
                let id = FunctionID("\(file.path):\(fn.name):\(index)")
                functionDeclarations.append(FunctionDeclaration(
                    id: id,
                    name: fn.name,
                    signature: fn.signature,
                    filePath: file.path,
                    parameters: fn.parameters.map {
                        ParameterInfo(label: $0.label, name: $0.name, type: $0.type)
                    },
                    returnType: fn.returnType,
                    accessibility: Accessibility(rawValue: fn.accessibility.rawValue) ?? .internal,
                    isStatic: fn.isStatic,
                    isAsync: fn.isAsync,
                    isThrows: fn.isThrows,
                    isMutating: fn.isMutating,
                    line: fn.line,
                    endLine: fn.endLine,
                    containingType: fn.containingType
                ))
            }

            for (index, call) in file.callSites.enumerated() {
                let id = CallSiteID("\(file.path):\(call.line):\(index)")
                callSites.append(CallSite(
                    id: id,
                    calledName: call.calledName,
                    filePath: file.path,
                    line: call.line,
                    containingFunction: call.containingFunction
                ))
            }
        }

        return IRStore(
            fileImports: fileImports,
            typeDeclarations: typeDeclarations,
            functionDeclarations: functionDeclarations,
            callSites: callSites
        )
    }

    private func buildGraphs(from ir: IRStore) throws -> GraphResult {
        print("Stage 3: Building graphs...")
        return try graphBuilder.buildGraphs(from: ir)
    }

    private func runSignals(on graphs: GraphResult) throws -> SignalResult {
        print("Stage 4: Running signals...")
        return try signalEngine.runSignals(on: graphs)
    }

    private func report(ir: IRStore, signals: SignalResult) {
        print("Stage 5: Reporting...")
        reporters.reportImports(ir.fileImports)
        reporters.reportSignals(
            signals,
            fileCount: ir.fileImports.count,
            typeCount: ir.typeDeclarations.count,
            functionCount: ir.functionDeclarations.count
        )
    }
}

public extension ExportFormat {
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .dot: return "dot"
        case .mermaid: return "md"
        }
    }
}
