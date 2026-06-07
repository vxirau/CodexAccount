import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: AccountProfileStore
    @State private var selectedProfileID: AccountProfile.ID?

    var selectedProfile: AccountProfile? {
        store.profiles.first { $0.id == selectedProfileID }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProfileID) {
                ForEach(store.profiles) { profile in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .lineLimit(1)
                        Text(profile.shortAccountID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(profile.id)
                }
                .onMove(perform: moveProfiles)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            Form {
                Section("Active Codex Account") {
                    LabeledContent("Account ID", value: store.activeSummary.displayName)
                    LabeledContent("Codex config profile", value: store.activeCodexConfigProfileName ?? "Default")
                    LabeledContent("Credential store", value: store.authCredentialStore)
                    if store.authCredentialStore != "file" {
                        Text("CodexAccount switches file-backed auth snapshots. Keyring-backed Codex credentials cannot be copied by this app.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    LabeledContent("Auth file", value: store.authURL.path)
                    Toggle("Quit Codex Desktop before switching", isOn: $store.quitCodexBeforeSwitching)
                }

                Section("Capture Current Account") {
                    TextField("Profile name", text: $store.draftProfileName)
                    HStack {
                        Button("Capture") {
                            store.captureCurrentProfile()
                        }
                        .keyboardShortcut(.defaultAction)

                        Button("Refresh") {
                            store.refresh()
                        }

                        Button("Prepare Login") {
                            store.signOutAndOpenLogin()
                        }
                    }
                }

                if let selectedProfile {
                    Section("Selected Profile") {
                        HStack(spacing: 12) {
                            AccountAvatarPreview(profile: selectedProfile, store: store, size: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedProfile.name)
                                    .font(.headline)
                                if let email = selectedProfile.displayEmail {
                                    Text(email)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        LabeledContent("Account ID", value: selectedProfile.shortAccountID)
                        Picker(
                            "Codex config profile",
                            selection: codexConfigProfileBinding(for: selectedProfile)
                        ) {
                            Text("Default").tag(String?.none)
                            ForEach(codexConfigProfileOptions(for: selectedProfile), id: \.self) { profileName in
                                if store.availableCodexConfigProfileNames.contains(profileName) {
                                    Text(profileName).tag(String?.some(profileName))
                                } else {
                                    Text("\(profileName) (missing)").tag(String?.some(profileName))
                                }
                            }
                        }
                        Text("Codex CLI/Desktop now uses named config profiles from ~/.codex/config.toml. This account will restore the selected profile when switched.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        LabeledContent("Captured", value: selectedProfile.capturedAt.formatted(date: .abbreviated, time: .shortened))

                        HStack {
                            Button("Choose Image...") {
                                chooseAvatarImage(for: selectedProfile)
                            }

                            Button("Use Default") {
                                store.resetProfileAvatar(selectedProfile)
                            }

                            Button("Switch") {
                                store.switchToProfile(selectedProfile)
                            }

                            Button("Delete", role: .destructive) {
                                store.deleteProfile(selectedProfile)
                                selectedProfileID = nil
                            }
                        }
                    }
                }

                Section("Recovery") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Back up the current auth file or open the local folders CodexAccount uses.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], alignment: .leading, spacing: 10) {
                            Button("Backup Now") {
                                store.backupNow()
                            }

                            Button("Reveal App Data") {
                                store.revealSupportFolder()
                            }

                            Button("Open .codex Folder") {
                                store.openCodexFolder()
                            }

                            Button("Open Codex") {
                                store.openCodexDesktop()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section("Status") {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text(store.statusMessage)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 2)
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .onAppear {
            store.refresh()
        }
    }

    private func chooseAvatarImage(for profile: AccountProfile) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose an image to use for this account in the menu bar dropdown."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        store.setProfileAvatar(profile, sourceURL: url)
    }

    private func moveProfiles(from source: IndexSet, to destination: Int) {
        store.moveProfiles(from: source, to: destination)
    }

    private func codexConfigProfileBinding(for profile: AccountProfile) -> Binding<String?> {
        Binding(
            get: {
                store.profiles.first { $0.id == profile.id }?.codexConfigProfileName
            },
            set: { newValue in
                store.updateCodexConfigProfile(for: profile, configProfileName: newValue)
            }
        )
    }

    private func codexConfigProfileOptions(for profile: AccountProfile) -> [String] {
        var options = store.availableCodexConfigProfileNames
        if let selected = profile.codexConfigProfileName, !options.contains(selected) {
            options.append(selected)
        }

        return options
    }
}

private struct AccountAvatarPreview: View {
    let profile: AccountProfile
    @ObservedObject var store: AccountProfileStore
    let size: CGFloat

    var body: some View {
        ZStack {
            if let image = customImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: AccountGradientColors.colors(for: profile.normalizedAvatarGradientIndex),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(profile.displayInitials)
                    .font(.system(size: size * (profile.displayInitials.count > 1 ? 0.38 : 0.48), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var customImage: NSImage? {
        guard let url = store.avatarURL(for: profile) else {
            return nil
        }

        return NSImage(contentsOf: url)
    }
}

private enum AccountGradientColors {
    static func colors(for index: Int) -> [Color] {
        let gradients = AccountAvatarPalette.gradients
        let normalized = gradients.isEmpty ? 0 : ((index % gradients.count) + gradients.count) % gradients.count
        return colors(for: gradients[normalized])
    }

    static func colors(for gradient: AccountAvatarGradient) -> [Color] {
        [
            Color(hex: gradient.startHex) ?? .accentColor,
            Color(hex: gradient.endHex) ?? .pink
        ]
    }
}

private extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6,
              let value = Int(cleaned, radix: 16) else {
            return nil
        }

        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}
