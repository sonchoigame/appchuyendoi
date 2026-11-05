import Foundation

/// Standalone macOS smoke test for 3105PATCH v9.
/// Run with: swiftc -parse-as-library PatchCodec.swift CodecSmoke.swift -o smoke && ./smoke fixture.3105
@main struct CodecSmoke {
    static func check(_ success: @autoclosure () -> Bool, _ message: String) {
        guard success() else { fatalError("CODEC TEST FAILED: \(message)") }
    }

    static func main() throws {
        let path = CommandLine.arguments[1]
        let sample = try Data(contentsOf: URL(fileURLWithPath: path))
        let initial = try PatchCodec.open(sample, password: "test-fixture")
        check(initial.schema == 9, "schema 9 must be decoded")
        check(initial.ruleCount == 2, "two independent file mappings")
        check(initial.bundles == ["com.garena.game.kgvn", "com.example.second"],
              "only application bundles should be listed")

        var passwordRejected = false
        do { _ = try PatchCodec.open(sample, password: "wrong-password") }
        catch { passwordRejected = true }
        check(passwordRejected, "wrong password must fail")

        let originalProject = initial.payload["project"] as! [String: Any]
        let originalRules = originalProject["rules"] as! [[String: Any]]
        let originalDirs = originalProject["directories"] as! [[String: Any]]
        let originalChecksums = initial.payload["replacementDigests"] as! [String: Data]

        let output = try PatchCodec.export(initial, old: "com.garena.game.kgvn", new: "com.nsmod.newid")
        check(output.starts(with: PatchCodec.magic), "correct 3105PATCH magic")
        let after = try PatchCodec.open(output, password: "nsmod")
        check(after.schema == 9, "schema preserved")
        check(after.bundles == ["com.nsmod.newid", "com.example.second"],
              "only requested application bundle renamed")
        check(after.ruleCount == initial.ruleCount, "rules count preserved")
        check(after.payload["replacementDigests"] as! [String: Data] == originalChecksums,
              "file digests unchanged")
        let newProject = after.payload["project"] as! [String: Any]
        let rules = newProject["rules"] as! [[String: Any]]
        let dirs = newProject["directories"] as! [[String: Any]]
        for i in rules.indices {
            check(rules[i]["id"] as? String == originalRules[i]["id"] as? String, "rule ID preserved")
            check(rules[i]["relativePath"] as? String == originalRules[i]["relativePath"] as? String,
                  "Documents/ and other relative paths preserved")
            check(rules[i]["replacementData"] as? Data == originalRules[i]["replacementData"] as? Data,
                  "binary rule data preserved")
            let kind = rules[i]["containerKind"] as? String ?? "application"
            let expected = kind == "application" ? "com.nsmod.newid" : originalRules[i]["bundleID"] as! String
            check(rules[i]["bundleID"] as? String == expected, "App Group mapping must not be changed")
        }
        for i in dirs.indices {
            check(dirs[i]["relativePath"] as? String == originalDirs[i]["relativePath"] as? String,
                  "directory structure preserved")
            let kind = dirs[i]["containerKind"] as? String ?? "application"
            let expected = kind == "application" ? "com.nsmod.newid" : originalDirs[i]["bundleID"] as! String
            check(dirs[i]["bundleID"] as? String == expected, "App Group directory must not be changed")
        }
        var oldRejected = false
        do { _ = try PatchCodec.open(output, password: "test-fixture") }
        catch { oldRejected = true }
        check(oldRejected, "new output must not unlock with old password")
        print("PASS: schema 9 decrypt -> rename Application bundle -> encrypt nsmod -> verify paths, bytes and App Group mapping.")
    }
}
