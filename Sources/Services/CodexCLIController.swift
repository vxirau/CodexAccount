import Foundation

enum CodexCLIController {
    struct Result {
        var succeeded: Bool
        var output: String
    }

    static func logout() -> Result {
        runLoginShellCommand("codex logout -c 'service_tier=\"flex\"'")
    }

    private static func runLoginShellCommand(_ command: String) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return Result(succeeded: process.terminationStatus == 0, output: output)
        } catch {
            return Result(succeeded: false, output: error.localizedDescription)
        }
    }
}
