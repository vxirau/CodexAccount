import Foundation

enum AuthFileInspector {
    static func readSummary(from url: URL) throws -> AuthSummary {
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            return AuthSummary(accountID: nil, accountEmail: nil, lastRefresh: nil)
        }

        let tokens = root["tokens"] as? [String: Any]
        let idToken = tokens?["id_token"] as? String
        return AuthSummary(
            accountID: tokens?["account_id"] as? String,
            accountEmail: tokens?["account_email"] as? String ?? email(fromIDToken: idToken),
            lastRefresh: root["last_refresh"] as? String
        )
    }

    private static func email(fromIDToken idToken: String?) -> String? {
        guard let payload = idToken?.split(separator: ".").dropFirst().first else {
            return nil
        }

        var base64 = String(payload)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data),
              let claims = object as? [String: Any] else {
            return nil
        }

        return claims["email"] as? String ?? claims["preferred_username"] as? String
    }
}
