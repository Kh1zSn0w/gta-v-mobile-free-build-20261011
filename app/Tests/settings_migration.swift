import Foundation

@main struct MigrationChecks {
    static func main() {
        let name = "personal-migration-test-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(120, forKey: "frameRateOption")
        defaults.set(5, forKey: "graphicsPreset")
        defaults.set(5, forKey: "lastGoodPreset")
        defaults.set(2.5, forKey: "lookSensitivity")
        defaults.set("http://192.168.1.115:8000", forKey: "assetServer")
        defaults.set(["fire": [0.8, 0.7]], forKey: "touchLayout.onFoot")
        PersonalSettingsMigration.run(defaults)
        precondition(defaults.integer(forKey: "frameRateCap") == 0)
        precondition(defaults.integer(forKey: "graphicsPreset") == 3)
        precondition(defaults.integer(forKey: "lastGoodPreset") == 3)
        precondition(defaults.integer(forKey: "renderHeight") == 720)
        precondition(defaults.integer(forKey: "cameraTouchMode") == 2)
        precondition(defaults.double(forKey: "mouseLookSensitivity") == 2.5)
        precondition(defaults.string(forKey: "assetServer") == "http://192.168.1.115:8000")
        precondition(defaults.dictionary(forKey: "touchLayout.onFoot") != nil)
        defaults.set(60, forKey: "frameRateCap")
        PersonalSettingsMigration.run(defaults)
        precondition(defaults.integer(forKey: "frameRateCap") == 60)
        defaults.removePersistentDomain(forName: name)
        PersonalSettingsMigration.run(defaults)
        precondition(defaults.object(forKey: "cameraTouchMode") == nil)
        precondition(defaults.object(forKey: "graphicsPreset") == nil)
        print("SETTINGS MIGRATION CHECKS PASSED: FPS, camera, graphics, layouts, server and idempotency.")
    }
}
