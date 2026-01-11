import Foundation
import HyenaGraphBuilder
import HyenaIRStore
import HyenaSignalEngine

public enum ExportFormat: String, CaseIterable {
    case json
    case dot
    case mermaid
}

public struct ExportOptions {
    public let format: ExportFormat
    public let outputPath: String?
    public let includeSignals: Bool
    public let includeGraphs: Bool
    
    public init(
        format: ExportFormat,
        outputPath: String? = nil,
        includeSignals: Bool = true,
        includeGraphs: Bool = true
    ) {
        self.format = format
        self.outputPath = outputPath
        self.includeSignals = includeSignals
        self.includeGraphs = includeGraphs
    }
}

public struct ExportResult {
    public let content: String
    public let format: ExportFormat
    
    public init(content: String, format: ExportFormat) {
        self.content = content
        self.format = format
    }
    
    public func write(to path: String) throws {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

public protocol GraphExporter {
    func export(
        ir: IRStore,
        graphs: GraphResult,
        signals: SignalResult
    ) -> ExportResult
}
