import AppKit
import Foundation

enum CodexDesktopController {
    static func quitCodexDesktop() {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex")
            .forEach { $0.terminate() }

        let script = """
        tell application "Codex" to quit
        """

        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        waitForCodexExit()
        terminateBundledHelpers()
    }

    static func openCodexDesktop() {
        let candidates = [
            URL(fileURLWithPath: "/Applications/Codex.app"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications")
                .appendingPathComponent("Codex.app")
        ]

        if let appURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
            return
        }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Codex"]
        try? process.run()
    }

    private static func waitForCodexExit() {
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex")
            if running.isEmpty {
                return
            }

            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }

        NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex")
            .forEach { $0.forceTerminate() }
    }

    private static func terminateBundledHelpers() {
        let patterns = [
            "/Applications/Codex.app/Contents/Resources/codex app-server",
            "/Applications/Codex.app/Contents/Resources/node_repl"
        ]

        for pattern in patterns {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            process.arguments = ["-f", pattern]
            try? process.run()
            process.waitUntilExit()
        }
    }
}
