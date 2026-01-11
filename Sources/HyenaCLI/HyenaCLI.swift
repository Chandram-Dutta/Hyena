import ArgumentParser
import Foundation

@main
struct HyenaCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hyena",
        abstract:
            """
            Hyena is a static analysis engine for Swift(more in future) codebases that parses and converts swift code into an Intermediate Representation (IR) format.
            It is then able to construct dependency graphs and perform various analyses on the code.
            """,
        version: "0.1.0",
        subcommands: [Scan.self],
        defaultSubcommand: Scan.self
    )
}
