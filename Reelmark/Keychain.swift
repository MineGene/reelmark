import Foundation
import Security

/// Keeps the user's TMDB access token in their login Keychain, never in
/// preferences or any plain file.
///
/// Note: Reelmark is signed ad hoc (no paid Apple developer account), so
/// macOS asks once after each update whether Reelmark may read the token.
/// Choosing "Always Allow" keeps it from asking again for that version.
enum Keychain {
    private static let service = "com.minegene.reelmark.tmdb"
    private static let account = "api-read-access-token"

    private static var item: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func readToken() -> String? {
        var query = item
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Returns false if the Keychain refused to save it.
    static func saveToken(_ token: String) -> Bool {
        deleteToken()
        var query = item
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrLabel as String] = "Reelmark – TMDB access token"
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func deleteToken() {
        _ = SecItemDelete(item as CFDictionary)
    }
}
