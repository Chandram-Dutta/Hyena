import ArgumentParser
import Foundation
import HyenaEngine

struct Scan: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Scan a directory"
    )

    @Argument(help: "The path to scan")
    var path: String

    mutating func run() throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ValidationError("Path does not exist: \(path)")
        }

        let engine = HyenaEngine()
        try engine.scan(path: path)
    }
}
