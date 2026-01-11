import ArgumentParser
import Foundation
import HyenaEngine
import HyenaReporters

struct Scan: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Scan a Swift codebase for architectural issues"
    )

    @Argument(help: "Path to the Swift project or directory to analyze")
    var path: String
    
    @Option(name: [.short, .long], help: "Export format: json, dot, or mermaid")
    var export: String?
    
    @Option(name: [.short, .long], help: "Output file path (prints to stdout if not specified)")
    var output: String?
    
    @Flag(name: [.short, .long], help: "Show detailed output including file imports")
    var verbose: Bool = false
    
    @Flag(name: [.short, .long], help: "Only show summary (no individual signals)")
    var quiet: Bool = false
    
    @Flag(name: .long, help: "Disable colored output")
    var noColor: Bool = false

    mutating func run() throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ValidationError("Path does not exist: \(path)")
        }
        
        if noColor {
            Console.useColors = false
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

        let options = ScanOptions(verbose: verbose, quiet: quiet)
        let engine = HyenaEngine()
        try engine.scan(path: path, exportFormat: exportFormat, outputPath: output, options: options)
    }
}
