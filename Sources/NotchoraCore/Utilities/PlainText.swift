import Foundation

/// Converts the small subset of Markdown used by chat previews into readable
/// plain text. Rendering still uses the full Markdown view; this is only for
/// one-line previews and search excerpts.
public enum PlainText {
    public static func preview(_ raw: String, limit: Int = 120) -> String {
        var text = raw
        let replacements: [(String, String)] = [
            (#"(?s)```[^\n]*\n(.*?)```"#, "$1"),
            (#"!\[([^\]]*)\]\([^)]*\)"#, "$1"),
            (#"\[([^\]]+)\]\([^)]*\)"#, "$1"),
            (#"<[^>]+>"#, " "),
            (#"(?m)^\s{0,3}#{1,6}\s*"#, ""),
            (#"(?m)^\s*>\s?"#, ""),
            (#"(?m)^\s*[-*+]\s+"#, ""),
            (#"(?m)^\s*\d+[.)]\s+"#, ""),
            (#"`([^`]*)`"#, "$1"),
            (#"(\*\*|__)(.*?)(\*\*|__)"#, "$2"),
            (#"(\*|_)(.*?)(\*|_)"#, "$2"),
            (#"~~(.*?)~~"#, "$1")
        ]
        for (pattern, template) in replacements {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
            }
        }
        text = text.replacingOccurrences(of: "\n", with: " ")
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > limit {
            text = String(text.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
        }
        return text
    }
}
