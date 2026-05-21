import Foundation

enum SalesforceRichTextFormatter {
    static func htmlToAttributedString(_ html: String) -> AttributedString? {
        let cleanedText = htmlToPlainText(html)
        guard cleanedText.isEmpty == false else { return nil }
        guard containsHTML(html), let data = html.data(using: .utf8) else {
            return AttributedString(cleanedText)
        }

        do {
            let nsAttributedString = try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
            let attributedString = AttributedString(nsAttributedString)
            return attributedString.characters.isEmpty ? AttributedString(cleanedText) : attributedString
        } catch {
            return AttributedString(cleanedText)
        }
    }

    static func htmlToPlainText(_ html: String) -> String {
        let normalizedHTML = html
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)</p\s*>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)<p[^>]*>"#, with: "", options: .regularExpression)

        let decodedText: String
        if containsHTML(normalizedHTML), let data = normalizedHTML.data(using: .utf8),
           let attributedString = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
           ) {
            decodedText = attributedString.string
        } else {
            decodedText = decodeHTMLEntities(in: normalizedHTML)
                .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        }

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
        guard let data = value.data(using: .utf8),
              let decoded = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ).string else {
            return value
        }
        return decoded
    }

    private static func normalizeDisplayWhitespace(_ value: String) -> String {
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
