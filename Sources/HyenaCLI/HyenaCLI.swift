import ArgumentParser
import Foundation

@main
struct HyenaCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hyena",
        abstract: "Hyena code analysis tool",
        version: "0.1.0",
        subcommands: [Scan.self],
        defaultSubcommand: Scan.self
    )
}
