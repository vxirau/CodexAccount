import Foundation

enum CodexConfigProfileManager {
    struct Summary: Equatable {
        var activeProfileName: String?
        var availableProfileNames: [String]
        var credentialStore: String?
    }

    static func readSummary(from configURL: URL) throws -> Summary {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return Summary(activeProfileName: nil, availableProfileNames: [], credentialStore: nil)
        }

        let content = try String(contentsOf: configURL, encoding: .utf8)
        return Summary(
            activeProfileName: topLevelStringValue(named: "profile", in: content),
            availableProfileNames: configProfileNames(in: content),
            credentialStore: topLevelStringValue(named: "cli_auth_credentials_store", in: content)
        )
    }

    static func setActiveProfile(_ profileName: String?, in configURL: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let existingContent: String
        if fileManager.fileExists(atPath: configURL.path) {
            existingContent = try String(contentsOf: configURL, encoding: .utf8)
        } else {
            existingContent = ""
        }

        let updatedContent = contentBySettingTopLevelProfile(profileName, in: existingContent)
        try updatedContent.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private static func configProfileNames(in content: String) -> [String] {
        var names: [String] = []
        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("[profiles."), line.hasSuffix("]") else {
                continue
            }

            var name = String(line.dropFirst("[profiles.".count).dropLast())
            if name.hasPrefix("\""), name.hasSuffix("\""), name.count >= 2 {
                name = String(name.dropFirst().dropLast())
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\\\", with: "\\")
            }
            if !name.isEmpty {
                names.append(name)
            }
        }

        return Array(Set(names)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func topLevelStringValue(named key: String, in content: String) -> String? {
        for rawLine in content.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                return nil
            }
            guard let value = parseAssignmentValue(named: key, from: trimmed) else {
                continue
            }

            return value
        }

        return nil
    }

    private static func parseAssignmentValue(named key: String, from line: String) -> String? {
        guard !line.hasPrefix("#") else {
            return nil
        }

        let pattern = "^\(NSRegularExpression.escapedPattern(for: key))\\s*=\\s*(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let valueRange = Range(match.range(at: 1), in: line) else {
            return nil
        }

        let rawValue = line[valueRange].split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            .trimmingCharacters(in: .whitespaces)
        if rawValue.hasPrefix("\""), rawValue.hasSuffix("\""), rawValue.count >= 2 {
            return String(rawValue.dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }

        return rawValue.isEmpty ? nil : rawValue
    }

    private static func contentBySettingTopLevelProfile(_ profileName: String?, in content: String) -> String {
        var lines = content.components(separatedBy: .newlines)
        var insertIndex = lines.count
        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                insertIndex = index
                break
            }
            if parseAssignmentValue(named: "profile", from: trimmed) != nil || trimmed.hasPrefix("profile ") || trimmed.hasPrefix("profile=") {
                if let profileName {
                    lines[index] = "profile = \(tomlQuoted(profileName))"
                } else {
                    lines.remove(at: index)
                }
                return normalizedContent(from: lines)
            }
        }

        guard let profileName else {
            return normalizedContent(from: lines)
        }

        let assignment = "profile = \(tomlQuoted(profileName))"
        lines.insert(assignment, at: insertIndex)
        return normalizedContent(from: lines)
    }

    private static func tomlQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func normalizedContent(from lines: [String]) -> String {
        var content = lines.joined(separator: "\n")
        if !content.hasSuffix("\n") {
            content += "\n"
        }
        return content
    }
}
