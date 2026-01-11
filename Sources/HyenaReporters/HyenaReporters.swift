import Foundation
import HyenaIRStore
import HyenaSignalEngine

public struct HyenaReporters {
    public init() {}

    public func reportImports(_ fileImports: [FileImports]) {
        print("\n--- File Imports ---\n")
        for file in fileImports {
            let fileName = (file.path as NSString).lastPathComponent
            if file.imports.isEmpty {
                print("\(fileName) → (none)")
            } else {
                print("\(fileName) → \(file.imports.joined(separator: ", "))")
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
}
