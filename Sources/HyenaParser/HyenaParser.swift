import Foundation
import SwiftParser
import SwiftSyntax

// MARK: - Parsed Output Structures

public struct ParsedFile: Sendable {
    public let path: String
    public let imports: [ParsedImport]
    public let types: [ParsedType]
    public let functions: [ParsedFunction]
    public let callSites: [ParsedCallSite]
    public let hasMainAttribute: Bool

    public init(
        path: String,
        imports: [ParsedImport] = [],
        types: [ParsedType] = [],
        functions: [ParsedFunction] = [],
        callSites: [ParsedCallSite] = [],
        hasMainAttribute: Bool = false
    ) {
        self.path = path
        self.imports = imports
        self.types = types
        self.functions = functions
        self.callSites = callSites
        self.hasMainAttribute = hasMainAttribute
    }

    public var importedModules: [String] {
        imports.map { $0.moduleName }
    }
}

public struct ParsedImport: Sendable, Equatable {
    public let moduleName: String
    public let isTestable: Bool
    public let line: Int

    public init(moduleName: String, isTestable: Bool = false, line: Int = 0) {
        self.moduleName = moduleName
        self.isTestable = isTestable
        self.line = line
    }
}

public struct ParsedType: Sendable, Equatable {
    public let name: String
    public let kind: TypeKind
    public let inheritedTypes: [String]
    public let accessibility: ParsedAccessibility
    public let line: Int
    public let endLine: Int
    public let attributes: [String]
    public let genericParameters: [String]

    public init(
        name: String,
        kind: TypeKind,
        inheritedTypes: [String] = [],
        accessibility: ParsedAccessibility = .internal,
        line: Int = 0,
        endLine: Int = 0,
        attributes: [String] = [],
        genericParameters: [String] = []
    ) {
        self.name = name
        self.kind = kind
        self.inheritedTypes = inheritedTypes
        self.accessibility = accessibility
        self.line = line
        self.endLine = endLine
        self.attributes = attributes
        self.genericParameters = genericParameters
    }
}

public enum TypeKind: String, Sendable, Equatable {
    case `struct`
    case `class`
    case `enum`
    case `protocol`
    case actor
}

public enum ParsedAccessibility: String, Sendable, Equatable {
    case `public`
    case `internal`
    case `private`
    case `fileprivate`
    case `open`
    case package
}

public struct ParsedFunction: Sendable, Equatable {
    public let name: String
    public let signature: String
    public let parameters: [ParsedParameter]
    public let returnType: String?
    public let accessibility: ParsedAccessibility
    public let isStatic: Bool
    public let isAsync: Bool
    public let isThrows: Bool
    public let isMutating: Bool
    public let line: Int
    public let endLine: Int
    public let containingType: String?

    public init(
        name: String,
        signature: String,
        parameters: [ParsedParameter] = [],
        returnType: String? = nil,
        accessibility: ParsedAccessibility = .internal,
        isStatic: Bool = false,
        isAsync: Bool = false,
        isThrows: Bool = false,
        isMutating: Bool = false,
        line: Int = 0,
        endLine: Int = 0,
        containingType: String? = nil
    ) {
        self.name = name
        self.signature = signature
        self.parameters = parameters
        self.returnType = returnType
        self.accessibility = accessibility
        self.isStatic = isStatic
        self.isAsync = isAsync
        self.isThrows = isThrows
        self.isMutating = isMutating
        self.line = line
        self.endLine = endLine
        self.containingType = containingType
    }
}

public struct ParsedParameter: Sendable, Equatable {
    public let label: String?
    public let name: String
    public let type: String

    public init(label: String?, name: String, type: String) {
        self.label = label
        self.name = name
        self.type = type
    }
}

public struct ParsedCallSite: Sendable, Equatable {
    public let calledName: String
    public let line: Int
    public let containingFunction: String?

    public init(calledName: String, line: Int, containingFunction: String? = nil) {
        self.calledName = calledName
        self.line = line
        self.containingFunction = containingFunction
    }
}

// MARK: - Parser

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
        let visitor = FullSyntaxVisitor(viewMode: .sourceAccurate)
        visitor.walk(syntax)

        return ParsedFile(
            path: filePath,
            imports: visitor.imports,
            types: visitor.types,
            functions: visitor.functions,
            callSites: visitor.callSites,
            hasMainAttribute: visitor.hasMainAttribute
        )
    }
}

// MARK: - Syntax Visitor

private final class FullSyntaxVisitor: SyntaxVisitor {
    var imports: [ParsedImport] = []
    var types: [ParsedType] = []
    var functions: [ParsedFunction] = []
    var callSites: [ParsedCallSite] = []
    var hasMainAttribute: Bool = false

    private var typeStack: [String] = []
    private var functionStack: [String] = []

    // MARK: - Imports

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let moduleName = node.path.map { $0.name.text }.joined(separator: ".")
        let isTestable = node.attributes.contains { attr in
            attr.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "testable"
        }
        let line = node.startLocation(converter: SourceLocationConverter(fileName: "", tree: node.root)).line

        imports.append(ParsedImport(
            moduleName: moduleName,
            isTestable: isTestable,
            line: line
        ))
        return .skipChildren
    }

    // MARK: - Type Declarations

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        addType(node, kind: .struct)
        typeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        typeStack.removeLast()
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        addType(node, kind: .class)
        typeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        typeStack.removeLast()
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        addType(node, kind: .enum)
        typeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        typeStack.removeLast()
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        addType(node, kind: .protocol)
        typeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
        typeStack.removeLast()
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        addType(node, kind: .actor)
        typeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: ActorDeclSyntax) {
        typeStack.removeLast()
    }

    private func addType(_ node: some DeclSyntaxProtocol, kind: TypeKind) {
        let (name, inheritedTypes, accessibility, attributes, generics) = extractTypeInfo(node)
        let converter = SourceLocationConverter(fileName: "", tree: node.root)
        let startLoc = node.startLocation(converter: converter)
        let endLoc = node.endLocation(converter: converter)

        if attributes.contains("main") {
            hasMainAttribute = true
        }

        types.append(ParsedType(
            name: name,
            kind: kind,
            inheritedTypes: inheritedTypes,
            accessibility: accessibility,
            line: startLoc.line,
            endLine: endLoc.line,
            attributes: attributes,
            genericParameters: generics
        ))
    }

    private func extractTypeInfo(_ node: some DeclSyntaxProtocol) -> (
        name: String,
        inheritedTypes: [String],
        accessibility: ParsedAccessibility,
        attributes: [String],
        generics: [String]
    ) {
        var name = ""
        var inheritedTypes: [String] = []
        var accessibility: ParsedAccessibility = .internal
        var attributes: [String] = []
        var generics: [String] = []

        if let structDecl = node.as(StructDeclSyntax.self) {
            name = structDecl.name.text
            inheritedTypes = extractInheritedTypes(structDecl.inheritanceClause)
            accessibility = extractAccessibility(structDecl.modifiers)
            attributes = extractAttributes(structDecl.attributes)
            generics = extractGenericParameters(structDecl.genericParameterClause)
        } else if let classDecl = node.as(ClassDeclSyntax.self) {
            name = classDecl.name.text
            inheritedTypes = extractInheritedTypes(classDecl.inheritanceClause)
            accessibility = extractAccessibility(classDecl.modifiers)
            attributes = extractAttributes(classDecl.attributes)
            generics = extractGenericParameters(classDecl.genericParameterClause)
        } else if let enumDecl = node.as(EnumDeclSyntax.self) {
            name = enumDecl.name.text
            inheritedTypes = extractInheritedTypes(enumDecl.inheritanceClause)
            accessibility = extractAccessibility(enumDecl.modifiers)
            attributes = extractAttributes(enumDecl.attributes)
            generics = extractGenericParameters(enumDecl.genericParameterClause)
        } else if let protocolDecl = node.as(ProtocolDeclSyntax.self) {
            name = protocolDecl.name.text
            inheritedTypes = extractInheritedTypes(protocolDecl.inheritanceClause)
            accessibility = extractAccessibility(protocolDecl.modifiers)
            attributes = extractAttributes(protocolDecl.attributes)
        } else if let actorDecl = node.as(ActorDeclSyntax.self) {
            name = actorDecl.name.text
            inheritedTypes = extractInheritedTypes(actorDecl.inheritanceClause)
            accessibility = extractAccessibility(actorDecl.modifiers)
            attributes = extractAttributes(actorDecl.attributes)
            generics = extractGenericParameters(actorDecl.genericParameterClause)
        }

        return (name, inheritedTypes, accessibility, attributes, generics)
    }

    private func extractInheritedTypes(_ clause: InheritanceClauseSyntax?) -> [String] {
        guard let clause = clause else { return [] }
        return clause.inheritedTypes.map { $0.type.trimmedDescription }
    }

    private func extractAccessibility(_ modifiers: DeclModifierListSyntax) -> ParsedAccessibility {
        for modifier in modifiers {
            switch modifier.name.text {
            case "public": return .public
            case "private": return .private
            case "fileprivate": return .fileprivate
            case "open": return .open
            case "package": return .package
            default: continue
            }
        }
        return .internal
    }

    private func extractAttributes(_ attrs: AttributeListSyntax) -> [String] {
        attrs.compactMap { element in
            element.as(AttributeSyntax.self)?.attributeName.trimmedDescription
        }
    }

    private func extractGenericParameters(_ clause: GenericParameterClauseSyntax?) -> [String] {
        guard let clause = clause else { return [] }
        return clause.parameters.map { $0.name.text }
    }

    // MARK: - Functions

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let signature = buildSignature(node)
        let parameters = extractParameters(node.signature.parameterClause)
        let returnType = node.signature.returnClause?.type.trimmedDescription
        let accessibility = extractAccessibility(node.modifiers)

        let isStatic = node.modifiers.contains { $0.name.text == "static" || $0.name.text == "class" }
        let isAsync = node.signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrows = node.signature.effectSpecifiers?.throwsClause != nil
        let isMutating = node.modifiers.contains { $0.name.text == "mutating" }

        let converter = SourceLocationConverter(fileName: "", tree: node.root)
        let startLoc = node.startLocation(converter: converter)
        let endLoc = node.endLocation(converter: converter)

        functions.append(ParsedFunction(
            name: name,
            signature: signature,
            parameters: parameters,
            returnType: returnType,
            accessibility: accessibility,
            isStatic: isStatic,
            isAsync: isAsync,
            isThrows: isThrows,
            isMutating: isMutating,
            line: startLoc.line,
            endLine: endLoc.line,
            containingType: typeStack.last
        ))

        functionStack.append(name)
        return .visitChildren
    }

    override func visitPost(_ node: FunctionDeclSyntax) {
        functionStack.removeLast()
    }

    private func buildSignature(_ node: FunctionDeclSyntax) -> String {
        var sig = "func \(node.name.text)"
        if let generics = node.genericParameterClause {
            sig += generics.trimmedDescription
        }
        sig += node.signature.parameterClause.trimmedDescription
        if let effects = node.signature.effectSpecifiers {
            if effects.asyncSpecifier != nil { sig += " async" }
            if effects.throwsClause != nil { sig += " throws" }
        }
        if let returnClause = node.signature.returnClause {
            sig += " \(returnClause.trimmedDescription)"
        }
        return sig
    }

    private func extractParameters(_ clause: FunctionParameterClauseSyntax) -> [ParsedParameter] {
        clause.parameters.map { param in
            ParsedParameter(
                label: param.firstName.text == "_" ? nil : param.firstName.text,
                name: param.secondName?.text ?? param.firstName.text,
                type: param.type.trimmedDescription
            )
        }
    }

    // MARK: - Call Sites

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let calledName = extractCalledName(node.calledExpression)
        let converter = SourceLocationConverter(fileName: "", tree: node.root)
        let loc = node.startLocation(converter: converter)

        callSites.append(ParsedCallSite(
            calledName: calledName,
            line: loc.line,
            containingFunction: functionStack.last
        ))
        return .visitChildren
    }

    private func extractCalledName(_ expr: ExprSyntax) -> String {
        if let declRef = expr.as(DeclReferenceExprSyntax.self) {
            return declRef.baseName.text
        } else if let memberAccess = expr.as(MemberAccessExprSyntax.self) {
            return memberAccess.declName.baseName.text
        }
        return expr.trimmedDescription
    }
}

// MARK: - Errors

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
