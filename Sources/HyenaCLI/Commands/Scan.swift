import ArgumentParser
import Foundation
import HyenaEngine
import HyenaReporters

struct Scan: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Scan a directory for code analysis"
    )

    @Argument(help: "The path to scan")
    var path: String
    
    @Option(name: [.short, .long], help: "Export format: json, dot, mermaid")
    var export: String?
    
    @Option(name: [.short, .long], help: "Output file path for export")
    var output: String?

    mutating func run() throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ValidationError("Path does not exist: \(path)")
        }
        
        let exportFormat: ExportFormat?
        if let formatString = export {
            guard let format = ExportFormat(rawValue: formatString.lowercased()) else {
                throw ValidationError("Invalid export format '\(formatString)'. Use: json, dot, or mermaid")
            }
            exportFormat = format
        } else {
            exportFormat = nil
        }

        let engine = HyenaEngine()
        try engine.scan(path: path, exportFormat: exportFormat, outputPath: output)
    }
}
