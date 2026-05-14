import AppKit
import Foundation

@MainActor
final class AccountProfileStore: ObservableObject {
    static let shared = AccountProfileStore()
    static let profilesDidChangeNotification = Notification.Name("CodexAccountProfilesDidChange")

    @Published private(set) var profiles: [AccountProfile] = []
    @Published private(set) var activeSummary = AuthSummary(accountID: nil, accountEmail: nil, lastRefresh: nil)
    @Published private(set) var statusMessage = ""
    @Published var draftProfileName = ""
    @Published var quitCodexBeforeSwitching = true {
        didSet {
            UserDefaults.standard.set(quitCodexBeforeSwitching, forKey: Self.quitBeforeSwitchingKey)
        }
    }

    private static let quitBeforeSwitchingKey = "quitCodexBeforeSwitching"

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        quitCodexBeforeSwitching = UserDefaults.standard.object(forKey: Self.quitBeforeSwitchingKey) as? Bool ?? true
        refresh()
    }

    var codexHomeURL: URL {
        if let override = ProcessInfo.processInfo.environment["CODEX_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }

    var authURL: URL {
        codexHomeURL.appendingPathComponent("auth.json", isDirectory: false)
    }

    var supportURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodexAccount", isDirectory: true)
    }

    private var legacySupportURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodexAccountSwitcher", isDirectory: true)
    }

    var profilesURL: URL {
        supportURL.appendingPathComponent("Profiles", isDirectory: true)
    }

    var backupsURL: URL {
        supportURL.appendingPathComponent("Backups", isDirectory: true)
    }

    var avatarsURL: URL {
        supportURL.appendingPathComponent("Avatars", isDirectory: true)
    }

    private var manifestURL: URL {
        supportURL.appendingPathComponent("profiles.json", isDirectory: false)
    }

    func refresh() {
        do {
            try ensureStorage()
            profiles = try loadProfiles()
            activeSummary = try readActiveSummary()
            statusMessage = "Ready"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func captureCurrentProfile() {
        let trimmedName = draftProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusMessage = "Enter a profile name first."
            return
        }

        do {
            try ensureAuthFileExists()
            try ensureStorage()

            let summary = try readActiveSummary()
            let id = UUID()
            let fileName = "\(id.uuidString).json"
            let destination = profilesURL.appendingPathComponent(fileName, isDirectory: false)
            try fileManager.copyItem(at: authURL, to: destination)

            let profile = AccountProfile(
                id: id,
                name: trimmedName,
                accountID: summary.accountID,
                accountEmail: summary.accountEmail,
                avatarGradientIndex: profiles.count,
                sortOrder: profiles.count,
                capturedAt: Date(),
                fileName: fileName
            )

            profiles.append(profile)
            normalizeProfileOrder()
            try saveProfiles()
            notifyProfilesDidChange()
            draftProfileName = ""
            activeSummary = summary
            statusMessage = "Captured \(profile.name)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func switchToProfile(_ profile: AccountProfile) {
        do {
            try ensureStorage()

            if quitCodexBeforeSwitching {
                CodexDesktopController.quitCodexDesktop()
            }

            let source = profilesURL.appendingPathComponent(profile.fileName, isDirectory: false)
            guard fileManager.fileExists(atPath: source.path) else {
                throw SwitcherError.missingProfileFile(profile.name)
            }

            _ = try backupCurrentAuth(reason: "pre-switch-\(safeFileComponent(profile.name))")
            try replaceAuthFile(with: source)
            activeSummary = try readActiveSummary()
            CodexBarController.refreshUsageStatus()
            statusMessage = "Switched to \(profile.name). CodexBar refresh started."
            if quitCodexBeforeSwitching {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    CodexDesktopController.openCodexDesktop()
                }
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func isActive(_ profile: AccountProfile) -> Bool {
        guard let profileAccountID = profile.accountID,
              let activeAccountID = activeSummary.accountID else {
            return false
        }

        return profileAccountID == activeAccountID
    }

    func signOutAndOpenLogin() {
        do {
            try ensureStorage()

            CodexDesktopController.quitCodexDesktop()

            if fileManager.fileExists(atPath: authURL.path) {
                let backup = try backupCurrentAuth(reason: "signed-out")
                try fileManager.removeItem(at: authURL)
                statusMessage = "Signed out. Backup saved: \(backup.lastPathComponent)"
            } else {
                statusMessage = "Already signed out."
            }

            activeSummary = AuthSummary(accountID: nil, accountEmail: nil, lastRefresh: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                CodexDesktopController.openCodexDesktop()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteProfile(_ profile: AccountProfile) {
        do {
            let source = profilesURL.appendingPathComponent(profile.fileName, isDirectory: false)
            if fileManager.fileExists(atPath: source.path) {
                try fileManager.removeItem(at: source)
            }

            profiles.removeAll { $0.id == profile.id }
            if let avatarURL = avatarURL(for: profile), fileManager.fileExists(atPath: avatarURL.path) {
                try fileManager.removeItem(at: avatarURL)
            }
            normalizeProfileOrder()
            try saveProfiles()
            notifyProfilesDidChange()
            statusMessage = "Deleted \(profile.name)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func setProfileAvatar(_ profile: AccountProfile, sourceURL: URL) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            statusMessage = "Profile not found."
            return
        }

        do {
            try ensureStorage()
            if let existingURL = avatarURL(for: profiles[index]), fileManager.fileExists(atPath: existingURL.path) {
                try fileManager.removeItem(at: existingURL)
            }

            let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension.lowercased()
            let fileName = "\(profile.id.uuidString)-\(UUID().uuidString).\(fileExtension)"
            let destination = avatarsURL.appendingPathComponent(fileName, isDirectory: false)
            try fileManager.copyItem(at: sourceURL, to: destination)
            profiles[index].avatarFileName = fileName
            try saveProfiles()
            notifyProfilesDidChange()
            statusMessage = "Updated image for \(profiles[index].name)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func resetProfileAvatar(_ profile: AccountProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            statusMessage = "Profile not found."
            return
        }

        do {
            if let existingURL = avatarURL(for: profiles[index]), fileManager.fileExists(atPath: existingURL.path) {
                try fileManager.removeItem(at: existingURL)
            }

            profiles[index].avatarFileName = nil
            try saveProfiles()
            notifyProfilesDidChange()
            statusMessage = "Reset image for \(profiles[index].name)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func avatarURL(for profile: AccountProfile) -> URL? {
        guard let avatarFileName = profile.avatarFileName, !avatarFileName.isEmpty else {
            return nil
        }

        return avatarsURL.appendingPathComponent(avatarFileName, isDirectory: false)
    }

    func moveProfiles(from source: IndexSet, to destination: Int) {
        profiles.move(fromOffsets: source, toOffset: destination)
        normalizeProfileOrder()

        do {
            try saveProfiles()
            notifyProfilesDidChange()
            statusMessage = "Updated profile order."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func backupNow() {
        do {
            let backup = try backupCurrentAuth(reason: "manual")
            statusMessage = "Backup saved: \(backup.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func revealSupportFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([supportURL])
    }

    func openCodexFolder() {
        NSWorkspace.shared.open(codexHomeURL)
    }

    func openCodexDesktop() {
        CodexDesktopController.openCodexDesktop()
    }

    private func readActiveSummary() throws -> AuthSummary {
        guard fileManager.fileExists(atPath: authURL.path) else {
            return AuthSummary(accountID: nil, accountEmail: nil, lastRefresh: nil)
        }

        return try AuthFileInspector.readSummary(from: authURL)
    }

    private func loadProfiles() throws -> [AccountProfile] {
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return []
        }

        let data = try Data(contentsOf: manifestURL)
        var loadedProfiles = try decoder.decode([AccountProfile].self, from: data)
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }

                return $0.sortOrder < $1.sortOrder
            }
        var changed = false

        for index in loadedProfiles.indices where loadedProfiles[index].sortOrder != index {
            loadedProfiles[index].sortOrder = index
            changed = true
        }

        for index in loadedProfiles.indices {
            let profileFile = profilesURL.appendingPathComponent(loadedProfiles[index].fileName, isDirectory: false)
            guard let summary = try? AuthFileInspector.readSummary(from: profileFile) else {
                continue
            }

            if loadedProfiles[index].accountID == nil, summary.accountID != nil {
                loadedProfiles[index].accountID = summary.accountID
                changed = true
            }
            if loadedProfiles[index].accountEmail == nil, summary.accountEmail != nil {
                loadedProfiles[index].accountEmail = summary.accountEmail
                changed = true
            }
        }

        if changed {
            let data = try encoder.encode(loadedProfiles)
            try data.write(to: manifestURL, options: [.atomic])
        }

        return loadedProfiles
    }

    private func normalizeProfileOrder() {
        for index in profiles.indices {
            profiles[index].sortOrder = index
        }
    }

    private func saveProfiles() throws {
        let data = try encoder.encode(profiles)
        try data.write(to: manifestURL, options: [.atomic])
    }

    private func notifyProfilesDidChange() {
        NotificationCenter.default.post(name: Self.profilesDidChangeNotification, object: self)
    }

    private func ensureStorage() throws {
        try migrateLegacyStorageIfNeeded()
        try fileManager.createDirectory(at: profilesURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: avatarsURL, withIntermediateDirectories: true)
    }

    private func migrateLegacyStorageIfNeeded() throws {
        guard fileManager.fileExists(atPath: legacySupportURL.path),
              !fileManager.fileExists(atPath: supportURL.path) else {
            return
        }

        try fileManager.createDirectory(at: supportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: legacySupportURL, to: supportURL)
    }

    private func ensureAuthFileExists() throws {
        guard fileManager.fileExists(atPath: authURL.path) else {
            throw SwitcherError.missingAuthFile(authURL.path)
        }
    }

    private func backupCurrentAuth(reason: String) throws -> URL {
        try ensureAuthFileExists()
        try ensureStorage()

        let stamp = Self.backupDateFormatter.string(from: Date())
        let fileName = "\(stamp)-\(reason).json"
        let destination = backupsURL.appendingPathComponent(fileName, isDirectory: false)
        try fileManager.copyItem(at: authURL, to: destination)
        return destination
    }

    private func replaceAuthFile(with source: URL) throws {
        try fileManager.createDirectory(at: codexHomeURL, withIntermediateDirectories: true)
        let temporaryURL = codexHomeURL.appendingPathComponent(".auth-switcher-\(UUID().uuidString).json", isDirectory: false)
        try fileManager.copyItem(at: source, to: temporaryURL)

        if fileManager.fileExists(atPath: authURL.path) {
            _ = try fileManager.replaceItemAt(authURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: authURL)
        }
    }

    private func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

enum SwitcherError: LocalizedError {
    case missingAuthFile(String)
    case missingProfileFile(String)

    var errorDescription: String? {
        switch self {
        case .missingAuthFile(let path):
            return "No Codex auth file found at \(path). Sign in to Codex first, then capture the account."
        case .missingProfileFile(let name):
            return "The saved auth snapshot for \(name) is missing."
        }
    }
}
