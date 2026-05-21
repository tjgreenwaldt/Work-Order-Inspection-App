import Foundation

enum SalesforceRichTextFormatter {
    static func htmlToAttributedString(_ html: String) -> AttributedString? {
        let cleanedText = htmlToPlainText(html)
        return cleanedText.isEmpty ? nil : AttributedString(cleanedText)
    }

    static func htmlToPlainText(_ html: String) -> String {
        // Salesforce rich text fields can contain simple HTML; the app displays readable plain text without preserving styling.
        let normalizedHTML = html
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)</p\s*>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)<p[^>]*>"#, with: "", options: .regularExpression)

        let decodedText = decodeHTMLEntities(in: normalizedHTML)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)

        return normalizeDisplayWhitespace(decodedText)
    }

    static func displayText(from htmlOrPlainText: String?) -> String {
        guard let htmlOrPlainText else { return "" }
        return htmlToPlainText(htmlOrPlainText)
    }

    private static func containsHTML(_ value: String) -> Bool {
        value.range(of: #"<[A-Za-z][^>]*>|</[A-Za-z][^>]*>|&[A-Za-z0-9#]+;"#, options: .regularExpression) != nil
    }

    private static func decodeHTMLEntities(in value: String) -> String {
        var result = value
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")

        let numericEntityPattern = #"&#(x?[0-9A-Fa-f]+);"#
        let matches = result.matches(of: try! Regex(numericEntityPattern))
        for match in matches.reversed() {
            let entity = String(match.0)
            let scalarText = entity
                .dropFirst(2)
                .dropLast()
            let value: UInt32?
            if scalarText.lowercased().hasPrefix("x") {
                value = UInt32(scalarText.dropFirst(), radix: 16)
            } else {
                value = UInt32(scalarText, radix: 10)
            }
            if let value, let scalar = UnicodeScalar(value) {
                result.replaceSubrange(match.range, with: String(Character(scalar)))
            }
        }
        return result
    }

    private static func normalizeDisplayWhitespace(_ value: String) -> String {
        // Collapse editor-generated spacing while preserving intentional line breaks for field instructions.
        let lines = value
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .components(separatedBy: .newlines)
            .map { line in
                line.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

        var normalizedLines: [String] = []
        for line in lines {
            if line.isEmpty {
                if normalizedLines.last?.isEmpty == false {
                    normalizedLines.append(line)
                }
            } else {
                normalizedLines.append(line)
            }
        }

        return normalizedLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
