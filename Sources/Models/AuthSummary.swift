import Foundation

struct AuthSummary: Equatable {
    var accountID: String?
    var accountEmail: String?
    var accountName: String?
    var profileImageURL: String?
    var lastRefresh: String?

    var displayName: String {
        if let accountEmail, !accountEmail.isEmpty {
            return accountEmail
        }

        guard let accountID, !accountID.isEmpty else {
            return "No active Codex account"
        }

        return accountID
    }
}
