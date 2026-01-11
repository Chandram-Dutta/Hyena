import Foundation
import SwiftParser
import SwiftSyntax

public struct ParsedFile: Sendable {
    public let path: String
    public let imports: [String]

    public init(path: String, imports: [String]) {
        self.path = path
        self.imports = imports
    }
}

public struct HyenaParser {
    public init() {}

    public func parse(at path: String) throws -> [ParsedFile] {
        let swiftFiles = try findSwiftFiles(at: path)
        return try swiftFiles.map { try parseFile(at: $0) }
    }

    private func findSwiftFiles(at path: String) throws -> [String] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw ParserError.pathNotFound(path)
        }

        if !isDirectory.boolValue {
            return path.hasSuffix(".swift") ? [path] : []
        }

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            throw ParserError.cannotEnumerate(path)
        }

        var swiftFiles: [String] = []
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".swift") {
                swiftFiles.append((path as NSString).appendingPathComponent(file))
            }
        }
        return swiftFiles
    }

    private func parseFile(at filePath: String) throws -> ParsedFile {
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        let syntax = Parser.parse(source: source)
        let imports = extractImports(from: syntax)
        return ParsedFile(path: filePath, imports: imports)
    }

    private func extractImports(from syntax: SourceFileSyntax) -> [String] {
        let visitor = ImportVisitor(viewMode: .sourceAccurate)
        visitor.walk(syntax)
        return visitor.imports
    }
}

private final class ImportVisitor: SyntaxVisitor {
    var imports: [String] = []

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let moduleName = node.path.map { $0.name.text }.joined(separator: ".")
        imports.append(moduleName)
        return .skipChildren
    }
}

public enum ParserError: Error, CustomStringConvertible {
    case pathNotFound(String)
    case cannotEnumerate(String)

    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .cannotEnumerate(let path):
            return "Cannot enumerate directory: \(path)"
        }
    }
}
