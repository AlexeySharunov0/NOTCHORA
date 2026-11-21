import AppKit
import SwiftUI

enum CodeHighlighter {
    private static let stringPattern = #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#

    static func highlight(_ code: String, language: String?, scheme: ColorScheme) -> AttributedString {
        let baseFont = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
        let baseColor = scheme == .dark
            ? NSColor(srgbRed: 0.88, green: 0.89, blue: 0.92, alpha: 1)
            : NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 1)
        let mutable = NSMutableAttributedString(
            string: code,
            attributes: [
                .font: baseFont,
                .foregroundColor: baseColor
            ]
        )
        let nsCode = code as NSString
        var protectedRanges: [NSRange] = []

        let stringColor = scheme == .dark
            ? NSColor(srgbRed: 0.56, green: 0.83, blue: 0.62, alpha: 1)
            : NSColor(srgbRed: 0.08, green: 0.45, blue: 0.28, alpha: 1)
        apply(
            pattern: stringPattern,
            color: stringColor,
            to: mutable,
            in: nsCode,
            options: []
        ) { range in
            protectedRanges.append(range)
        }

        let normalized = (language ?? "").lowercased()
        let hashComments = ["python", "py", "ruby", "rb", "shell", "sh", "bash", "zsh", "yaml", "yml", "toml", "r"].contains(normalized)
        let commentPattern = hashComments
            ? #"(?m)#.*$"#
            : #"(?m)//.*$|(?s)/\*.*?\*/"#
        let commentColor = scheme == .dark
            ? NSColor(srgbRed: 0.48, green: 0.50, blue: 0.55, alpha: 1)
            : NSColor(srgbRed: 0.45, green: 0.47, blue: 0.51, alpha: 1)
        apply(pattern: commentPattern, color: commentColor, to: mutable, in: nsCode, protectedRanges: protectedRanges) { range in
            if !overlapsProtected(range, protectedRanges) {
                protectedRanges.append(range)
            }
        }

        let keywordColor = scheme == .dark
            ? NSColor(srgbRed: 0.80, green: 0.57, blue: 0.98, alpha: 1)
            : NSColor(srgbRed: 0.55, green: 0.18, blue: 0.72, alpha: 1)
        let keywords = keywordSet(for: normalized)
        if !keywords.isEmpty {
            let escaped = keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            apply(
                pattern: "\\b(?:\(escaped))\\b",
                color: keywordColor,
                to: mutable,
                in: nsCode,
                protectedRanges: protectedRanges
            )
        }

        let typeColor = scheme == .dark
            ? NSColor(srgbRed: 0.45, green: 0.69, blue: 0.99, alpha: 1)
            : NSColor(srgbRed: 0.10, green: 0.34, blue: 0.72, alpha: 1)
        apply(
            pattern: #"\b[A-Z][A-Za-z0-9_]{1,}\b"#,
            color: typeColor,
            to: mutable,
            in: nsCode,
            protectedRanges: protectedRanges
        )

        let numberColor = scheme == .dark
            ? NSColor(srgbRed: 0.93, green: 0.73, blue: 0.42, alpha: 1)
            : NSColor(srgbRed: 0.66, green: 0.39, blue: 0.04, alpha: 1)
        apply(
            pattern: #"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#,
            color: numberColor,
            to: mutable,
            in: nsCode,
            protectedRanges: protectedRanges
        )

        if normalized == "json" || normalized == "jsonc" {
            let keyColor = scheme == .dark
                ? NSColor(srgbRed: 0.50, green: 0.72, blue: 1.0, alpha: 1)
                : NSColor(srgbRed: 0.09, green: 0.33, blue: 0.69, alpha: 1)
            apply(
                pattern: #""(?:\\.|[^"\\])*"(?=\s*:)"#,
                color: keyColor,
                to: mutable,
                in: nsCode
            )
        }

        return AttributedString(mutable)
    }

    private static func apply(
        pattern: String,
        color: NSColor,
        to string: NSMutableAttributedString,
        in source: NSString,
        options: NSRegularExpression.Options = [],
        protectedRanges: [NSRange] = [],
        onMatch: ((NSRange) -> Void)? = nil
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let matches = regex.matches(in: source as String, range: NSRange(location: 0, length: source.length))
        for match in matches {
            if !protectedRanges.isEmpty && overlapsProtected(match.range, protectedRanges) {
                onMatch?(match.range)
                continue
            }
            string.addAttribute(.foregroundColor, value: color, range: match.range)
            onMatch?(match.range)
        }
    }

    private static func overlapsProtected(_ range: NSRange, _ protected: [NSRange]) -> Bool {
        protected.contains { NSIntersectionRange($0, range).length > 0 }
    }

    private static func keywordSet(for language: String) -> [String] {
        let common = ["true", "false", "null", "nil", "return", "if", "else", "for", "while", "break", "continue", "import", "from", "class", "struct", "enum", "func", "let", "var", "const", "public", "private", "static", "async", "await", "try", "catch", "throw", "switch", "case", "default", "new", "this", "self", "super", "in", "is", "as", "extends", "implements", "interface", "type", "def", "elif", "elif", "pass", "with", "yield", "lambda"]
        switch language {
        case "swift":
            return ["actor", "associatedtype", "async", "await", "break", "case", "catch", "class", "continue", "default", "defer", "do", "else", "enum", "extension", "fallthrough", "false", "for", "func", "guard", "if", "import", "in", "indirect", "init", "inout", "internal", "is", "let", "nil", "open", "operator", "private", "protocol", "public", "repeat", "rethrows", "return", "self", "static", "struct", "subscript", "super", "switch", "throw", "throws", "true", "try", "typealias", "var", "where", "while", "some", "any", "nonisolated", "isolated", "sending"]
        case "python", "py":
            return ["and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del", "elif", "else", "except", "False", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda", "None", "nonlocal", "not", "or", "pass", "raise", "return", "True", "try", "while", "with", "yield"]
        case "javascript", "js", "typescript", "ts", "tsx", "jsx":
            return ["async", "await", "break", "case", "catch", "class", "const", "continue", "default", "delete", "do", "else", "export", "extends", "false", "finally", "for", "function", "if", "import", "in", "instanceof", "let", "new", "null", "of", "return", "static", "super", "switch", "this", "throw", "true", "try", "typeof", "var", "void", "while", "yield"]
        case "rust":
            return ["as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while"]
        case "go", "golang":
            return ["break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map", "package", "range", "return", "select", "struct", "switch", "type", "var", "nil", "true", "false"]
        case "sql":
            return ["select", "from", "where", "join", "left", "right", "inner", "outer", "on", "group", "by", "order", "having", "limit", "offset", "insert", "into", "values", "update", "set", "delete", "create", "table", "alter", "drop", "and", "or", "not", "null", "as", "distinct", "union"]
        case "bash", "sh", "zsh", "shell":
            return ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "function", "in", "select", "until", "return", "exit", "local", "export", "source", "alias", "echo", "cd"]
        case "json", "jsonc":
            return ["true", "false", "null"]
        default:
            return common
        }
    }
}
