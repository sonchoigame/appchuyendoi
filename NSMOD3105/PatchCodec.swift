import Foundation
import CryptoKit
import CommonCrypto
import Security

enum PatchFailure: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}

/// Compatible with the 3105PATCH plist envelope used by schemas 1...9.
/// Decoding via dictionaries retains unknown schema 4...9 metadata and operations.
enum PatchCodec {
    static let magic = Data("3105PATCH\0".utf8)
    static let outputPassword = "nsmod"
    static let maximumSize = 512 * 1024 * 1024
    static let rounds = 250_000

    struct Opened {
        let envelope: [String: Any]
        let payload: [String: Any]
        let bundles: [String]
        let schema: Int
        let name: String
        let ruleCount: Int
    }

    private static func fail(_ message: String) -> PatchFailure { .message(message) }

    private static func plist(_ data: Data) throws -> [String: Any] {
        let value = try PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        )
        guard let dictionary = value as? [String: Any] else {
            throw fail("Dữ liệu plist trong file không hợp lệ.")
        }
        return dictionary
    }

    private static func encoded(_ value: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    }

    private static func blob(_ map: [String: Any], _ key: String, length: Int? = nil) throws -> Data {
        guard let data = map[key] as? Data, length.map({ data.count == $0 }) ?? true else {
            throw fail("Trường \(key) không hợp lệ.")
        }
        return data
    }

    private static func keyAAD(_ packageID: String, _ version: Int) -> Data {
        Data("3105PATCH/v\(version)/key/\(packageID)".utf8)
    }

    private static func payloadAAD(_ packageID: String, _ version: Int) -> Data {
        Data("3105PATCH/v\(version)/payload/\(packageID)".utf8)
    }

    private static func derive(_ password: String, salt: Data, iterations: Int) throws -> Data {
        let passwordCount = password.utf8.count
        guard passwordCount > 0, passwordCount <= 1024,
              salt.count == 16, (100_000...1_000_000).contains(iterations) else {
            throw fail("Thông số mật khẩu / PBKDF2 không hợp lệ.")
        }
        var result = Data(count: 32)
        let status: Int32 = password.withCString { ptr in
            salt.withUnsafeBytes { saltBytes in
                result.withUnsafeMutableBytes { resultBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        ptr,
                        passwordCount,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        resultBytes.bindMemory(to: UInt8.self).baseAddress,
                        32
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw fail("Không thể tạo khóa giải mã.") }
        return result
    }

    private static func decrypt(_ encrypted: Data, key: Data, aad: Data) throws -> Data {
        guard key.count == 32, encrypted.count >= 28 else {
            throw fail("Dữ liệu AES-GCM không hợp lệ.")
        }
        do {
            let box = try AES.GCM.SealedBox(combined: encrypted)
            return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
        } catch {
            throw fail("Mật khẩu không đúng hoặc file .3105 bị lỗi.")
        }
    }

    private static func encrypt(_ data: Data, key: Data, aad: Data) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: SymmetricKey(data: key), authenticating: aad)
        guard let combined = sealed.combined else { throw fail("Không tạo được AES-GCM.") }
        return combined
    }

    private static func random(_ count: Int) throws -> Data {
        var output = Data(count: count)
        let status = output.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }
        guard status == errSecSuccess else { throw fail("Không tạo được khóa ngẫu nhiên.") }
        return output
    }

    static func validBundleID(_ value: String) -> Bool {
        guard value.utf8.count > 0, value.utf8.count <= 255 else { return false }
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count >= 2 else { return false }
        for part in components {
            guard !part.isEmpty, part.first != "-", part.last != "-" else { return false }
            for scalar in part.unicodeScalars {
                let n = scalar.value
                guard (48...57).contains(n) || (65...90).contains(n)
                    || (97...122).contains(n) || n == 45 else { return false }
            }
        }
        return true
    }

    private static func collectBundles(_ project: [String: Any]) throws -> [String] {
        var result: [String] = []
        let declared = project["bundleIdentifiers"] as? [String] ?? []
        for id in declared {
            guard validBundleID(id) else { throw fail("Bundle ID nguồn không hợp lệ.") }
            if !result.contains(id) { result.append(id) }
        }
        for field in ["rules", "directories"] {
            let entries = project[field] as? [[String: Any]] ?? []
            for entry in entries {
                guard let id = entry["bundleID"] as? String else {
                    throw fail("Mục \(field) không hợp lệ.")
                }
                let kind = entry["containerKind"] as? String ?? "application"
                if kind == "application" {
                    guard validBundleID(id) else { throw fail("Bundle ID nguồn không hợp lệ.") }
                    if !result.contains(id) { result.append(id) }
                }
            }
        }
        return result
    }

    private static func checkDigests(_ payload: [String: Any]) throws -> Int {
        guard let project = payload["project"] as? [String: Any],
              let rules = project["rules"] as? [[String: Any]],
              let checksums = payload["replacementDigests"] as? [String: Data],
              checksums.count == rules.count else {
            throw fail("Danh sách file hoặc checksum của patch không hợp lệ.")
        }
        var seen = Set<String>()
        for rule in rules {
            guard let id = rule["id"] as? String,
                  let data = rule["replacementData"] as? Data,
                  let expected = checksums[id], expected.count == 32,
                  seen.insert(id).inserted,
                  Data(SHA256.hash(data: data)) == expected else {
                throw fail("Checksum của một file patch không khớp.")
            }
        }
        return rules.count
    }

    static func open(_ data: Data, password: String) throws -> Opened {
        guard data.count > magic.count, data.count <= maximumSize,
              data.starts(with: magic) else {
            throw fail("File không phải 3105PATCH hoặc vượt quá 512 MB.")
        }
        let envelope = try plist(Data(data.dropFirst(magic.count)))
        guard let schema = envelope["schemaVersion"] as? Int,
              (1...9).contains(schema) else {
            throw fail("Schema 3105 chưa hỗ trợ (chỉ 1–9).")
        }
        guard let packageID = envelope["packageID"] as? String,
              let protected = envelope["isPasswordProtected"] as? Bool else {
            throw fail("Envelope thiếu thông tin.")
        }
        let key: Data
        if protected {
            guard let iterations = envelope["kdfIterations"] as? Int else {
                throw fail("File thiếu kdfIterations.")
            }
            let salt = try blob(envelope, "kdfSalt", length: 16)
            let wrapped = try blob(envelope, "wrappedContentKey")
            let wrappingKey = try derive(password, salt: salt, iterations: iterations)
            let aadVersion = envelope["keyAADVersion"] as? Int ?? schema
            guard (1...9).contains(aadVersion) else { throw fail("AAD version không hợp lệ.") }
            key = try decrypt(wrapped, key: wrappingKey, aad: keyAAD(packageID, aadVersion))
        } else {
            key = try blob(envelope, "publicContentKey", length: 32)
        }
        guard key.count == 32,
              Data(SHA256.hash(data: key)) == (try blob(envelope, "keyFingerprint", length: 32)) else {
            throw fail("Khóa giải mã không khớp.")
        }
        let ciphertext = try blob(envelope, "encryptedPayload")
        let payload = try plist(decrypt(ciphertext, key: key, aad: payloadAAD(packageID, schema)))
        guard let project = payload["project"] as? [String: Any],
              project["id"] as? String == packageID else {
            throw fail("Project ID không khớp.")
        }
        let count = try checkDigests(payload)
        let bundles = try collectBundles(project)
        guard !bundles.isEmpty else { throw fail("Patch không có Bundle ID ứng dụng.") }
        return Opened(
            envelope: envelope, payload: payload, bundles: bundles,
            schema: schema, name: project["name"] as? String ?? "Patch", ruleCount: count
        )
    }

    static func export(_ loaded: Opened, old: String, new: String) throws -> Data {
        guard loaded.bundles.contains(old),
              validBundleID(new), old != new, !loaded.bundles.contains(new) else {
            throw fail("Bundle ID mới không hợp lệ hoặc đã tồn tại.")
        }
        var payload = loaded.payload
        guard var project = payload["project"] as? [String: Any] else {
            throw fail("Không đọc được project.")
        }

        if var declared = project["bundleIdentifiers"] as? [String] {
            declared = declared.map { $0 == old ? new : $0 }
            project["bundleIdentifiers"] = declared
        }
        for field in ["rules", "directories"] {
            var entries = project[field] as? [[String: Any]] ?? []
            for index in entries.indices {
                let kind = entries[index]["containerKind"] as? String ?? "application"
                if kind == "application", entries[index]["bundleID"] as? String == old {
                    entries[index]["bundleID"] = new
                }
            }
            // Preserve relativePath, replacementData, operations and AppGroup mappings.
            if project[field] != nil { project[field] = entries }
        }
        payload["project"] = project
        _ = try checkDigests(payload)

        let version = loaded.schema
        guard let packageID = loaded.envelope["packageID"] as? String else {
            throw fail("Thiếu Package ID.")
        }
        let contentKey = try random(32)
        let salt = try random(16)
        let wrappingKey = try derive(outputPassword, salt: salt, iterations: rounds)
        var envelope = loaded.envelope
        envelope["isPasswordProtected"] = true
        envelope["keyAADVersion"] = version
        envelope["kdfSalt"] = salt
        envelope["kdfIterations"] = rounds
        envelope["publicContentKey"] = nil
        envelope["wrappedContentKey"] = try encrypt(
            contentKey, key: wrappingKey, aad: keyAAD(packageID, version)
        )
        envelope["keyFingerprint"] = Data(SHA256.hash(data: contentKey))
        envelope["encryptedPayload"] = try encrypt(
            encoded(payload), key: contentKey, aad: payloadAAD(packageID, version)
        )
        let output = magic + (try encoded(envelope))

        // Fail closed: independently re-open output with "nsmod" before sharing.
        let verification = try open(output, password: outputPassword)
        guard verification.bundles.contains(new), !verification.bundles.contains(old),
              verification.ruleCount == loaded.ruleCount else {
            throw fail("File mới không vượt qua bước xác minh.")
        }
        return output
    }
}
