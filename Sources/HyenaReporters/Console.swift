import Foundation

public enum Console {
    public enum Color: String {
        case reset = "\u{001B}[0m"
        case bold = "\u{001B}[1m"
        case dim = "\u{001B}[2m"
        case red = "\u{001B}[31m"
        case green = "\u{001B}[32m"
        case yellow = "\u{001B}[33m"
        case blue = "\u{001B}[34m"
        case magenta = "\u{001B}[35m"
        case cyan = "\u{001B}[36m"
        case white = "\u{001B}[37m"
        case brightRed = "\u{001B}[91m"
        case brightGreen = "\u{001B}[92m"
        case brightYellow = "\u{001B}[93m"
        case brightBlue = "\u{001B}[94m"
        case brightMagenta = "\u{001B}[95m"
        case brightCyan = "\u{001B}[96m"
        case gray = "\u{001B}[90m"
    }
    
    nonisolated(unsafe) public static var useColors: Bool = {
        guard let term = ProcessInfo.processInfo.environment["TERM"], !term.isEmpty else {
            return false
        }
        return isatty(STDOUT_FILENO) != 0
    }()
    
    public static func styled(_ text: String, _ colors: Color...) -> String {
        guard useColors else { return text }
        let prefix = colors.map { $0.rawValue }.joined()
        return "\(prefix)\(text)\(Color.reset.rawValue)"
    }
    
    public static func error(_ text: String) -> String {
        styled(text, .bold, .red)
    }
    
    public static func warning(_ text: String) -> String {
        styled(text, .yellow)
    }
    
    public static func success(_ text: String) -> String {
        styled(text, .green)
    }
    
    public static func info(_ text: String) -> String {
        styled(text, .blue)
    }
    
    public static func dim(_ text: String) -> String {
        styled(text, .dim)
    }
    
    public static func bold(_ text: String) -> String {
        styled(text, .bold)
    }
    
    public static func highlight(_ text: String) -> String {
        styled(text, .bold, .cyan)
    }
    
    public static func file(_ path: String) -> String {
        styled((path as NSString).lastPathComponent, .cyan)
    }
    
    public static func number(_ value: Int) -> String {
        styled("\(value)", .bold, .white)
    }
}

public enum Symbols {
    public static var checkmark: String { Console.useColors ? "✓" : "[OK]" }
    public static var cross: String { Console.useColors ? "✗" : "[FAIL]" }
    public static var warning: String { Console.useColors ? "⚠" : "[WARN]" }
    public static var info: String { Console.useColors ? "ℹ" : "[INFO]" }
    public static var bullet: String { Console.useColors ? "•" : "-" }
    public static var arrow: String { Console.useColors ? "→" : "->" }
    public static var boxTop: String { Console.useColors ? "┌" : "+" }
    public static var boxBottom: String { Console.useColors ? "└" : "+" }
    public static var boxVertical: String { Console.useColors ? "│" : "|" }
    public static var boxHorizontal: String { Console.useColors ? "─" : "-" }
    public static var boxTopRight: String { Console.useColors ? "┐" : "+" }
    public static var boxBottomRight: String { Console.useColors ? "┘" : "+" }
    public static var spinner: [String] { Console.useColors ? ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"] : ["-", "\\", "|", "/"] }
}

public struct Box {
    private let width: Int
    
    public init(width: Int = 60) {
        self.width = width
    }
    
    public func top(title: String = "") -> String {
        if title.isEmpty {
            return Symbols.boxTop + String(repeating: Symbols.boxHorizontal, count: width - 2) + Symbols.boxTopRight
        }
        let titleDisplay = " \(title) "
        let remaining = width - 2 - titleDisplay.count
        let leftPad = remaining / 2
        let rightPad = remaining - leftPad
        return Symbols.boxTop + String(repeating: Symbols.boxHorizontal, count: leftPad) + Console.bold(titleDisplay) + String(repeating: Symbols.boxHorizontal, count: rightPad) + Symbols.boxTopRight
    }
    
    public func middle(_ text: String) -> String {
        let visibleLength = stripAnsi(text).count
        let padding = max(0, width - 4 - visibleLength)
        return "\(Symbols.boxVertical) \(text)\(String(repeating: " ", count: padding)) \(Symbols.boxVertical)"
    }
    
    public func bottom() -> String {
        return Symbols.boxBottom + String(repeating: Symbols.boxHorizontal, count: width - 2) + Symbols.boxBottomRight
    }
    
    public func separator() -> String {
        return Symbols.boxVertical + String(repeating: Symbols.boxHorizontal, count: width - 2) + Symbols.boxVertical
    }
    
    private func stripAnsi(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
    }
}

public struct ProgressReporter {
    private let stages: [String]
    private var currentStage = 0
    
    public init(stages: [String]) {
        self.stages = stages
    }
    
    public mutating func start(_ stage: String) {
        let stageNum = currentStage + 1
        let total = stages.count
        let prefix = Console.dim("[\(stageNum)/\(total)]")
        print("\(prefix) \(Console.bold(stage))...")
    }
    
    public mutating func complete(_ message: String? = nil) {
        let checkmark = Console.success(Symbols.checkmark)
        if let message = message {
            print("    \(checkmark) \(Console.dim(message))")
        }
        currentStage += 1
    }
    
    public func finish() {
        print("")
    }
}
