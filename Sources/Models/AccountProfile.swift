import Foundation

struct AccountProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var accountID: String?
    var accountEmail: String?
    var codexConfigProfileName: String?
    var avatarFileName: String?
    var avatarInitials: String?
    var avatarGradientIndex: Int
    var sortOrder: Int
    var capturedAt: Date
    var fileName: String

    init(
        id: UUID,
        name: String,
        accountID: String?,
        accountEmail: String?,
        codexConfigProfileName: String? = nil,
        avatarFileName: String? = nil,
        avatarInitials: String? = nil,
        avatarGradientIndex: Int = 0,
        sortOrder: Int = 0,
        capturedAt: Date,
        fileName: String
    ) {
        self.id = id
        self.name = name
        self.accountID = accountID
        self.accountEmail = accountEmail
        self.codexConfigProfileName = codexConfigProfileName
        self.avatarFileName = avatarFileName
        self.avatarInitials = avatarInitials
        self.avatarGradientIndex = avatarGradientIndex
        self.sortOrder = sortOrder
        self.capturedAt = capturedAt
        self.fileName = fileName
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case accountID
        case accountEmail
        case codexConfigProfileName
        case avatarFileName
        case avatarInitials
        case avatarGradientIndex
        case sortOrder
        case capturedAt
        case fileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        accountID = try container.decodeIfPresent(String.self, forKey: .accountID)
        accountEmail = try container.decodeIfPresent(String.self, forKey: .accountEmail)
        codexConfigProfileName = try container.decodeIfPresent(String.self, forKey: .codexConfigProfileName)
        avatarFileName = try container.decodeIfPresent(String.self, forKey: .avatarFileName)
        avatarInitials = try container.decodeIfPresent(String.self, forKey: .avatarInitials)
        avatarGradientIndex = try container.decodeIfPresent(Int.self, forKey: .avatarGradientIndex) ?? 0
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        fileName = try container.decode(String.self, forKey: .fileName)
    }

    var shortAccountID: String {
        guard let accountID, !accountID.isEmpty else {
            return "Unknown account"
        }

        if accountID.count <= 18 {
            return accountID
        }

        return String(accountID.prefix(10)) + "..." + String(accountID.suffix(6))
    }

    var displayEmail: String? {
        guard let accountEmail, !accountEmail.isEmpty else {
            return nil
        }

        return accountEmail
    }

    var displayInitials: String {
        let configured = avatarInitials?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !configured.isEmpty {
            return String(configured.prefix(2)).uppercased()
        }

        let fallback = name.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "?"
        return fallback.uppercased()
    }

    var normalizedAvatarGradientIndex: Int {
        let count = AccountAvatarPalette.gradients.count
        guard count > 0 else {
            return 0
        }

        return ((avatarGradientIndex % count) + count) % count
    }
}

struct AccountAvatarGradient: Codable, Equatable {
    var startHex: String
    var endHex: String
}

enum AccountAvatarPalette {
    static let gradients: [AccountAvatarGradient] = [
        .init(startHex: "#FF8A7A", endHex: "#FFC36A"),
        .init(startHex: "#5E8CFF", endHex: "#78E0D1"),
        .init(startHex: "#9B7CFF", endHex: "#F47CC4"),
        .init(startHex: "#47C278", endHex: "#B6E36E"),
        .init(startHex: "#FF7A59", endHex: "#D9477A"),
        .init(startHex: "#5C6BC0", endHex: "#26C6DA")
    ]
}
