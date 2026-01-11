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

    public func scan(path: String) throws {
        print("Starting Hyena analysis for: \(path)")

        let parsedFiles = try runIngestion(at: path)
        let ir = buildIR(from: parsedFiles)
        let graphs = try buildGraphs(from: ir)
        let signals = try runSignals(on: graphs)
        try report(ir: ir, signals: signals)

        print("Analysis complete")
    }

    private func runIngestion(at path: String) throws -> [ParsedFile] {
        print("Stage 1: Running ingestion...")
        return try parser.parse(at: path)
    }

    private func buildIR(from parsedFiles: [ParsedFile]) -> IRStore {
        print("Stage 2: Building IR...")
        let fileImports = parsedFiles.map { FileImports(path: $0.path, imports: $0.imports) }
        return IRStore(fileImports: fileImports)
    }

    private func buildGraphs(from ir: IRStore) throws -> GraphResult {
        print("Stage 3: Building graphs...")
        return try graphBuilder.buildGraphs(from: ir)
    }

    private func runSignals(on graphs: GraphResult) throws -> SignalResult {
        print("Stage 4: Running signals...")
        return try signalEngine.runSignals(on: graphs)
    }

    private func report(ir: IRStore, signals: SignalResult) throws {
        print("Stage 5: Reporting...")
        reporters.reportImports(ir.fileImports)
        reporters.reportSignals(signals)
    }
}
