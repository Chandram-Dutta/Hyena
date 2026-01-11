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
        let ir = try buildIR(from: parsedFiles)
        let graphs = try buildGraphs(from: ir)
        let signals = try runSignals(on: graphs)
        try report(signals: signals)

        print("Analysis complete")
    }

    private func runIngestion(at path: String) throws -> [String] {
        print("Stage 1: Running ingestion...")
        return try parser.parse(at: path)
    }

    private func buildIR(from parsedFiles: [String]) throws -> IRStore {
        print("Stage 2: Building IR...")
        return try irStore.buildIR(from: parsedFiles)
    }

    private func buildGraphs(from ir: IRStore) throws -> GraphResult {
        print("Stage 3: Building graphs...")
        return try graphBuilder.buildGraphs(from: ir)
    }

    private func runSignals(on graphs: GraphResult) throws -> SignalResult {
        print("Stage 4: Running signals...")
        return try signalEngine.runSignals(on: graphs)
    }

    private func report(signals: SignalResult) throws {
        print("Stage 5: Reporting...")
        try reporters.report(signals: signals)
    }
}
