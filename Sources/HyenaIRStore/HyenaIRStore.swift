import Foundation

// MARK: - IR Storage Container

/// The main storage container for the Intermediate Representation
/// This holds all parsed files, symbols, and relations before graph construction
public struct IRStore {
    public let files: [FileEntity]
    public let symbols: [SymbolEntity]
    public let relations: [RelationEntity]
    public let fileImports: [FileImports]

    public init(
        files: [FileEntity] = [],
        symbols: [SymbolEntity] = [],
        relations: [RelationEntity] = [],
        fileImports: [FileImports] = []
    ) {
        self.files = files
        self.symbols = symbols
        self.relations = relations
        self.fileImports = fileImports
    }

    public var stats: IRStats {
        IRStats(
            fileCount: files.count,
            symbolCount: symbols.count,
            relationCount: relations.count
        )
    }
}

public struct IRStats {
    public let fileCount: Int
    public let symbolCount: Int
    public let relationCount: Int

    public init(fileCount: Int, symbolCount: Int, relationCount: Int) {
        self.fileCount = fileCount
        self.symbolCount = symbolCount
        self.relationCount = relationCount
    }
}

// MARK: - File Entity

/// Represents a source file in the codebase
public struct FileEntity {
    public let id: FileID
    public let path: String
    public let language: Language
    public let size: Int
    public let lineCount: Int
    public let symbolIDs: [SymbolID]
    public let metadata: FileMetadata

    public init(
        id: FileID,
        path: String,
        language: Language,
        size: Int,
        lineCount: Int,
        symbolIDs: [SymbolID] = [],
        metadata: FileMetadata = FileMetadata()
    ) {
        self.id = id
        self.path = path
        self.language = language
        self.size = size
        self.lineCount = lineCount
        self.symbolIDs = symbolIDs
        self.metadata = metadata
    }
}

public struct FileID: Hashable, Codable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

public struct FileMetadata {
    public let lastModified: Date?
    public let encoding: String
    public let hash: String?

    public init(
        lastModified: Date? = nil,
        encoding: String = "utf-8",
        hash: String? = nil
    ) {
        self.lastModified = lastModified
        self.encoding = encoding
        self.hash = hash
    }
}

// MARK: - Symbol Entity

/// Represents a code symbol (class, function, variable, etc.)
public struct SymbolEntity {
    public let id: SymbolID
    public let name: String
    public let kind: SymbolKind
    public let location: SourceLocation
    public let accessibility: Accessibility
    public let attributes: [String]
    public let signature: String?
    public let documentation: String?
    public let metadata: SymbolMetadata

    public init(
        id: SymbolID,
        name: String,
        kind: SymbolKind,
        location: SourceLocation,
        accessibility: Accessibility = .internal,
        attributes: [String] = [],
        signature: String? = nil,
        documentation: String? = nil,
        metadata: SymbolMetadata = SymbolMetadata()
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.location = location
        self.accessibility = accessibility
        self.attributes = attributes
        self.signature = signature
        self.documentation = documentation
        self.metadata = metadata
    }
}

public struct SymbolID: Hashable, Codable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

public enum SymbolKind: String, Codable {
    case `class`
    case `struct`
    case `enum`
    case `protocol`
    case `extension`
    case function
    case method
    case initializer
    case property
    case variable
    case constant
    case typeAlias
    case associatedType
    case `operator`
    case macro
    case module
    case namespace
    case unknown
}

public enum Accessibility: String, Codable {
    case `public`
    case `internal`
    case `private`
    case `fileprivate`
    case `open`
    case packagePublic = "package"
}

public struct SourceLocation {
    public let fileID: FileID
    public let line: Int
    public let column: Int
    public let endLine: Int?
    public let endColumn: Int?

    public init(
        fileID: FileID,
        line: Int,
        column: Int,
        endLine: Int? = nil,
        endColumn: Int? = nil
    ) {
        self.fileID = fileID
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
    }
}

public struct SymbolMetadata {
    public let isGeneric: Bool
    public let isAsync: Bool
    public let isThrows: Bool
    public let isMutating: Bool
    public let isStatic: Bool
    public let isOverride: Bool
    public let complexity: Int?

    public init(
        isGeneric: Bool = false,
        isAsync: Bool = false,
        isThrows: Bool = false,
        isMutating: Bool = false,
        isStatic: Bool = false,
        isOverride: Bool = false,
        complexity: Int? = nil
    ) {
        self.isGeneric = isGeneric
        self.isAsync = isAsync
        self.isThrows = isThrows
        self.isMutating = isMutating
        self.isStatic = isStatic
        self.isOverride = isOverride
        self.complexity = complexity
    }
}

// MARK: - Relation Entity

/// Represents a relationship between symbols
public struct RelationEntity {
    public let id: RelationID
    public let source: SymbolID
    public let target: SymbolID
    public let kind: RelationKind
    public let location: SourceLocation?
    public let metadata: RelationMetadata

    public init(
        id: RelationID,
        source: SymbolID,
        target: SymbolID,
        kind: RelationKind,
        location: SourceLocation? = nil,
        metadata: RelationMetadata = RelationMetadata()
    ) {
        self.id = id
        self.source = source
        self.target = target
        self.kind = kind
        self.location = location
        self.metadata = metadata
    }
}

public struct RelationID: Hashable, Codable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

public enum RelationKind: String, Codable {
    // Type relationships
    case inherits
    case conforms
    case extends
    case implements

    // Usage relationships
    case calls
    case references
    case instantiates
    case imports

    // Containment relationships
    case contains
    case defines
    case declares

    // Dependency relationships
    case dependsOn
    case uses
    case requires

    // Other
    case overrides
    case shadows
    case unknown
}

public struct RelationMetadata {
    public let isConditional: Bool
    public let isOptional: Bool
    public let isDirect: Bool
    public let weight: Double

    public init(
        isConditional: Bool = false,
        isOptional: Bool = false,
        isDirect: Bool = true,
        weight: Double = 1.0
    ) {
        self.isConditional = isConditional
        self.isOptional = isOptional
        self.isDirect = isDirect
        self.weight = weight
    }
}

// MARK: - Language

public enum Language: String, Codable {
    case swift
    case objectiveC = "objective-c"
    case c
    case cpp = "c++"
    case python
    case javascript
    case typescript
    case go
    case rust
    case java
    case kotlin
    case unknown
}

// MARK: - File Imports (Phase 2 vertical slice)

public struct FileImports: Sendable {
    public let path: String
    public let imports: [String]

    public init(path: String, imports: [String]) {
        self.path = path
        self.imports = imports
    }
}

// MARK: - IR Store Builder

/// The main interface for building IR from parsed data
public struct HyenaIRStore {
    public init() {}

    public func buildFileImports(files: [(path: String, imports: [String])]) -> [FileImports] {
        files.map { FileImports(path: $0.path, imports: $0.imports) }
    }

    /// Build IR from parsed files
    /// This is a placeholder - actual implementation will process parser output
    public func buildIR(from parsedFiles: [String]) throws -> IRStore {
        return IRStore(
            files: [],
            symbols: [],
            relations: []
        )
    }

    /// Validate the IR store for consistency
    public func validate(_ store: IRStore) -> [ValidationError] {
        var errors: [ValidationError] = []

        // Check that all symbol references in files exist
        let symbolIDSet = Set(store.symbols.map { $0.id })
        for file in store.files {
            for symbolID in file.symbolIDs {
                if !symbolIDSet.contains(symbolID) {
                    errors.append(.missingSymbolInFile(symbolID, fileID: file.id))
                }
            }
        }

        // Check that all relation endpoints exist
        for relation in store.relations {
            if !symbolIDSet.contains(relation.source) {
                errors.append(.missingSymbolInRelation(relation.source, relationID: relation.id))
            }
            if !symbolIDSet.contains(relation.target) {
                errors.append(.missingSymbolInRelation(relation.target, relationID: relation.id))
            }
        }

        // Check that all symbol locations reference valid files
        let fileIDSet = Set(store.files.map { $0.id })
        for symbol in store.symbols {
            if !fileIDSet.contains(symbol.location.fileID) {
                errors.append(.missingFileForSymbol(symbol.location.fileID, symbolID: symbol.id))
            }
        }

        return errors
    }
}

// MARK: - Validation

public enum ValidationError: Error, CustomStringConvertible {
    case missingSymbolInFile(SymbolID, fileID: FileID)
    case missingSymbolInRelation(SymbolID, relationID: RelationID)
    case missingFileForSymbol(FileID, symbolID: SymbolID)
    case duplicateID(String)
    case invalidRelation(RelationID, reason: String)

    public var description: String {
        switch self {
        case .missingSymbolInFile(let symbolID, let fileID):
            return "Symbol \(symbolID.value) referenced in file \(fileID.value) does not exist"
        case .missingSymbolInRelation(let symbolID, let relationID):
            return
                "Symbol \(symbolID.value) referenced in relation \(relationID.value) does not exist"
        case .missingFileForSymbol(let fileID, let symbolID):
            return "File \(fileID.value) for symbol \(symbolID.value) does not exist"
        case .duplicateID(let id):
            return "Duplicate ID found: \(id)"
        case .invalidRelation(let relationID, let reason):
            return "Invalid relation \(relationID.value): \(reason)"
        }
    }
}
