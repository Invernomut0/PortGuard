import Foundation
import IOKit
import Security

@Observable
final class LicenseManager {
    private(set) var isPro: Bool = false
    private(set) var activationError: String? = nil
    var isValidating: Bool = false

    private let gumroadProductPermalink = "portguard" // ← sostituisci con il tuo permalink reale
    private let keychainKey = "com.portguard.app.licenseKey"

    init() {
        if let saved = loadKeyFromKeychain() {
            Task { await validate(key: saved, persist: false) }
        }
    }

    func activate(key: String) async {
        await validate(key: key, persist: true)
    }

    func deactivate() {
        deleteKeyFromKeychain()
        isPro = false
    }

    private func validate(key: String, persist: Bool) async {
        await MainActor.run { isValidating = true; activationError = nil }

        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = URLRequest(url: URL(string: "https://api.gumroad.com/v2/licenses/verify")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "product_permalink=\(gumroadProductPermalink)&license_key=\(trimmed)".data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success {
                if persist { saveKeyToKeychain(trimmed) }
                await MainActor.run { isPro = true; isValidating = false }
            } else {
                await MainActor.run {
                    activationError = "Invalid license key. Please check and try again."
                    isValidating = false
                }
            }
        } catch {
            await MainActor.run {
                activationError = "Network error. Please check your connection."
                isValidating = false
            }
        }
    }

    private func saveKeyToKeychain(_ key: String) {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}
