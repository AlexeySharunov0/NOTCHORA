import AppKit
import Combine
import SwiftUI

enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case code(language: String?, code: String)
    case quote(String)
    case bullet(text: String, depth: Int)
    case ordered(number: Int, text: String, depth: Int)
    case table(headers: [String], rows: [[String]])
    case divider
}

enum MarkdownParser {
    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var index = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            let joined = paragraph.joined(separator: " ")
            if !joined.trimmingCharacters(in: .whitespaces).isEmpty {
                blocks.append(.paragraph(joined))
            }
            paragraph.removeAll()
        }

        while index < lines.count {
            let rawLine = lines[index]
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                flushParagraph()
                let fence = String(line.prefix(3))
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(.code(
                    language: language.isEmpty ? nil : language,
                    code: codeLines.joined(separator: "\n")
                ))
                continue
            }

            if let heading = headingMatch(line) {
                flushParagraph()
                blocks.append(.heading(level: heading.level, text: heading.text))
                index += 1
                continue
            }

            if isDivider(line) {
                flushParagraph()
                blocks.append(.divider)
                index += 1
                continue
            }

            if line.hasPrefix(">") {
                flushParagraph()
                var quoteLines: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix(">") else { break }
                    var stripped = String(candidate.dropFirst())
                    if stripped.hasPrefix(" ") { stripped.removeFirst() }
                    quoteLines.append(stripped)
                    index += 1
                }
                blocks.append(.quote(quoteLines.joined(separator: "\n")))
                continue
            }

            if let table = parseTable(lines: lines, index: &index) {
                flushParagraph()
                blocks.append(.table(headers: table.headers, rows: table.rows))
                continue
            }

            if let bullet = bulletMatch(rawLine) {
                flushParagraph()
                blocks.append(.bullet(text: bullet.text, depth: bullet.depth))
                index += 1
                continue
            }

            if let ordered = orderedMatch(rawLine) {
                flushParagraph()
                blocks.append(.ordered(number: ordered.number, text: ordered.text, depth: ordered.depth))
                index += 1
                continue
            }

            paragraph.append(line)
            index += 1
        }
        flushParagraph()
        return blocks
    }

    private static func headingMatch(_ line: String) -> (level: Int, text: String)? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        guard rest.first == " " else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (hashes, text)
    }

    private static func isDivider(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        return stripped == "---" || stripped == "***" || stripped == "___"
    }

    private static func bulletMatch(_ rawLine: String) -> (text: String, depth: Int)? {
        let indent = rawLine.prefix { $0 == " " || $0 == "\t" }.count
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        for marker in ["- ", "* ", "+ ", "• "] {
            if trimmed.hasPrefix(marker) {
                return (String(trimmed.dropFirst(marker.count)), indent / 2)
            }
        }
        return nil
    }

    private static func orderedMatch(_ rawLine: String) -> (number: Int, text: String, depth: Int)? {
        let indent = rawLine.prefix { $0 == " " || $0 == "\t" }.count
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        let pattern = #"^(\d{1,3})[.)]\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let numberRange = Range(match.range(at: 1), in: trimmed),
              let textRange = Range(match.range(at: 2), in: trimmed),
              let number = Int(trimmed[numberRange]) else {
            return nil
        }
        return (number, String(trimmed[textRange]), indent / 2)
    }

    private static func parseTable(lines: [String], index: inout Int) -> (headers: [String], rows: [[String]])? {
        guard index + 1 < lines.count else { return nil }
        let header = lines[index].trimmingCharacters(in: .whitespaces)
        let separator = lines[index + 1].trimmingCharacters(in: .whitespaces)
        guard header.contains("|"), separator.contains("|"), separator.contains("-") else { return nil }
        let separatorCells = splitCells(separator)
        guard !separatorCells.isEmpty, separatorCells.allSatisfy({ cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            return trimmed.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " } && trimmed.contains("-")
        }) else { return nil }

        let headers = splitCells(header)
        var rows: [[String]] = []
        var cursor = index + 2
        while cursor < lines.count {
            let row = lines[cursor].trimmingCharacters(in: .whitespaces)
            guard row.contains("|"), !row.isEmpty else { break }
            rows.append(splitCells(row))
            cursor += 1
        }
        index = cursor
        return (headers, rows)
    }

    private static func splitCells(_ line: String) -> [String] {
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("|") { value.removeFirst() }
        if value.hasSuffix("|") { value.removeLast() }
        return value
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

struct MarkdownView: View {
    let text: String
    var isStreaming = false

    @Environment(\.colorScheme) private var colorScheme

    private var blocks: [MarkdownBlock] { MarkdownParser.parse(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if text.isEmpty && isStreaming {
                StreamingDots()
                    .padding(.vertical, 3)
            } else {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
                if isStreaming {
                    HStack(spacing: 5) {
                        StreamingDots()
                        Text("Generating")
                            .font(.nCaption)
                            .foregroundStyle(Color.nTextTertiary)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            InlineMarkdownText(
                text: text,
                font: headingFont(level),
                color: .nTextPrimary
            )
            .padding(.top, level <= 2 ? 4 : 2)
            .accessibilityAddTraits(.isHeader)
        case let .paragraph(text):
            InlineMarkdownText(text: text, font: .nBody, color: .nTextPrimary)
                .lineSpacing(2.2)
                .fixedSize(horizontal: false, vertical: true)
        case let .code(language, code):
            CodeBlockView(language: language, code: code)
        case let .quote(text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.nAccent.opacity(0.55))
                    .frame(width: 2)
                InlineMarkdownText(text: text, font: .nBody, color: .nTextSecondary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 1)
        case let .bullet(text, depth):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Circle()
                    .fill(Color.nTextTertiary)
                    .frame(width: 3.5, height: 3.5)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 2 }
                InlineMarkdownText(text: text, font: .nBody, color: .nTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(depth) * 13)
        case let .ordered(number, text, depth):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(number).")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.nTextTertiary)
                    .frame(minWidth: 15, alignment: .trailing)
                InlineMarkdownText(text: text, font: .nBody, color: .nTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(depth) * 13)
        case let .table(headers, rows):
            MarkdownTable(headers: headers, rows: rows)
        case .divider:
            Hairline()
                .padding(.vertical, 3)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .system(size: 18, weight: .semibold)
        case 2: .system(size: 15.5, weight: .semibold)
        case 3: .system(size: 14, weight: .semibold)
        default: .system(size: 13.5, weight: .semibold)
        }
    }
}

struct InlineMarkdownText: View {
    let text: String
    var font: Font = .nBody
    var color: Color = .nTextPrimary

    var body: some View {
        Text(attributed)
            .font(font)
            .foregroundStyle(color)
            .tint(Color.nAccent)
    }

    private var attributed: AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible
        guard var result = try? AttributedString(markdown: text, options: options) else {
            return AttributedString(text)
        }
        result.font = font
        result.foregroundColor = color
        for run in result.runs {
            if run.inlinePresentationIntent?.contains(.code) == true {
                result[run.range].font = .system(size: 11.5, weight: .regular, design: .monospaced)
                result[run.range].foregroundColor = .nAccent
            }
            if run.link != nil {
                result[run.range].foregroundColor = .nAccent
                result[run.range].underlineStyle = .single
            }
        }
        return result
    }
}

struct CodeBlockView: View {
    let language: String?
    let code: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.nTextTertiary)
                Text((language ?? "code").lowercased())
                    .font(.nCaption)
                    .foregroundStyle(Color.nTextTertiary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.4))
                        copied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9, weight: .semibold))
                        Text(copied ? "Copied" : "Copy")
                            .font(.nCaption)
                    }
                    .foregroundStyle(copied ? Color.nSuccess : Color.nTextSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .help("Copy code")
            }
            .padding(.horizontal, 11)
            .frame(height: 29)

            Hairline()

            ScrollView(.horizontal, showsIndicators: false) {
                Text(CodeHighlighter.highlight(code, language: language, scheme: colorScheme))
                    .font(.nCode)
                    .lineSpacing(2)
                    .padding(12)
                    .fixedSize(horizontal: true, vertical: false)
                    .textSelection(.enabled)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.nCodeBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.nHairline, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct MarkdownTable: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                        InlineMarkdownText(text: header, font: .nSmallMedium, color: .nTextPrimary)
                            .padding(.vertical, 7)
                            .frame(minWidth: 70, alignment: .leading)
                    }
                }
                .background(Color.primary.opacity(0.035))
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    GridRow {
                        ForEach(0..<headers.count, id: \.self) { column in
                            InlineMarkdownText(
                                text: column < row.count ? row[column] : "",
                                font: .nSmall,
                                color: .nTextSecondary
                            )
                            .padding(.vertical, 6)
                            .frame(minWidth: 70, alignment: .leading)
                        }
                    }
                    if index < rows.count - 1 {
                        GridRow {
                            Color.nHairline
                                .frame(height: 1)
                                .gridCellColumns(max(headers.count, 1))
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.nHairline, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct StreamingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.nAccent.opacity(0.35 + Double((phase + index) % 3) * 0.22))
                    .frame(width: 4, height: 4)
            }
        }
        .onReceive(timer) { _ in
            guard !reduceMotion else { return }
            phase = (phase + 1) % 3
        }
        .accessibilityLabel("Generating response")
    }
}
