import Foundation

enum CodexBarController {
    static func refreshUsageStatus() {
        let process = Process()
        process.executableURL = codexBarCLIURL()
        process.arguments = ["usage", "--provider", "codex", "--source", "oauth", "--format", "json"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
    }

    private static func codexBarCLIURL() -> URL {
        let candidates = [
            "/opt/homebrew/bin/codexbar",
            "/usr/local/bin/codexbar",
            "/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI"
        ]

        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: path)
        }

        return URL(fileURLWithPath: "/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI")
    }
}
