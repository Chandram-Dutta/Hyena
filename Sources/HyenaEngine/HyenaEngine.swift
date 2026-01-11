import Foundation
import HyenaGraphBuilder
import HyenaIRStore
import HyenaParser
import HyenaReporters
import HyenaSignalEngine

public struct ScanOptions {
    public let verbose: Bool
    public let quiet: Bool
    
    public init(verbose: Bool = false, quiet: Bool = false) {
        self.verbose = verbose
        self.quiet = quiet
    }
}

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

    public func scan(
        path: String,
        exportFormat: ExportFormat? = nil,
        outputPath: String? = nil,
        options: ScanOptions = ScanOptions()
    ) throws {
        let startTime = Date()
        
        reporters.printHeader(path: path)

        let parsedFiles = try runIngestion(at: path)
        let ir = buildIR(from: parsedFiles)
        let graphs = try buildGraphs(from: ir)
        let signals = try runSignals(on: graphs)
        
        if let format = exportFormat {
            try export(ir: ir, graphs: graphs, signals: signals, format: format, outputPath: outputPath)
        } else {
            report(ir: ir, signals: signals, options: options)
        }

        let duration = Date().timeIntervalSince(startTime)
        reporters.printCompletion(duration: duration)
    }
    
    private func export(
        ir: IRStore,
        graphs: GraphResult,
        signals: SignalResult,
        format: ExportFormat,
        outputPath: String?
    ) throws {
        reporters.printStage(5, of: 5, "Exporting as \(format.rawValue.uppercased())")
        let result = reporters.export(ir: ir, graphs: graphs, signals: signals, format: format)
        
        if let path = outputPath {
            try result.write(to: path)
            reporters.printStageComplete("Written to \(path)")
        } else {
            print("")
            print(result.content)
        }
    }

    private func runIngestion(at path: String) throws -> [ParsedFile] {
        reporters.printStage(1, of: 5, "Parsing Swift files")
        let files = try parser.parse(at: path)
        reporters.printStageComplete("Found \(files.count) files")
        return files
    }

    private func buildIR(from parsedFiles: [ParsedFile]) -> IRStore {
        reporters.printStage(2, of: 5, "Building intermediate representation")

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

        let ir = IRStore(
            fileImports: fileImports,
            typeDeclarations: typeDeclarations,
            functionDeclarations: functionDeclarations,
            callSites: callSites
        )
        
        reporters.printStageComplete("\(typeDeclarations.count) types, \(functionDeclarations.count) functions")
        return ir
    }

    private func buildGraphs(from ir: IRStore) throws -> GraphResult {
        reporters.printStage(3, of: 5, "Building dependency graphs")
        let result = try graphBuilder.buildGraphs(from: ir)
        reporters.printStageComplete("File, inheritance, and call graphs ready")
        return result
    }

    private func runSignals(on graphs: GraphResult) throws -> SignalResult {
        reporters.printStage(4, of: 5, "Analyzing for issues")
        let result = try signalEngine.runSignals(on: graphs)
        let issueCount = result.signals.count
        if issueCount == 0 {
            reporters.printStageComplete("No issues found")
        } else {
            reporters.printStageComplete("Found \(issueCount) potential issues")
        }
        return result
    }

    private func report(ir: IRStore, signals: SignalResult, options: ScanOptions) {
        reporters.printStage(5, of: 5, "Generating report")
        
        if options.verbose {
            reporters.reportImports(ir.fileImports, verbose: true)
        }
        
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
