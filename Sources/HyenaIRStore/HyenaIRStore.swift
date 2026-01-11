import Foundation

public struct HyenaIRStore {
    public init() {}

    public func buildIR(from parsedFiles: [String]) throws -> IRStore {
        let items = parsedFiles.map { IRItem(id: $0) }
        return IRStore(items: items)
    }
}

public struct IRStore {
    public let items: [IRItem]

    public init(items: [IRItem]) {
        self.items = items
    }
}

public struct IRItem {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}
