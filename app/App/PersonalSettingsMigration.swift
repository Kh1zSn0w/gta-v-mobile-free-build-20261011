import Foundation

enum PersonalSettingsMigration {
    static func run(_ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: "personalRelease3Migrated") else { return }
        if let fps = defaults.object(forKey: "frameRateOption") as? Int,
           defaults.object(forKey: "frameRateCap") == nil {
            defaults.set(fps >= 120 ? 0 : fps >= 60 ? 60 : 30, forKey: "frameRateCap")
        }
        if defaults.integer(forKey: "graphicsPreset") == 5 {
            // The old Extreme slot is Kevin's Max slot. Keep its prior 720p profile affordable.
            defaults.set(3, forKey: "graphicsPreset")
            if defaults.integer(forKey: "renderHeight") == 0 { defaults.set(720, forKey: "renderHeight") }
            if defaults.integer(forKey: "lastGoodPreset") == 5 { defaults.set(3, forKey: "lastGoodPreset") }
        }
        if defaults.object(forKey: "cameraTouchMode") == nil,
           defaults.object(forKey: "frameRateOption") != nil {
            defaults.set(2, forKey: "cameraTouchMode")
            if let look = defaults.object(forKey: "lookSensitivity") as? Double {
                defaults.set(min(15, max(0.2, look)), forKey: "mouseLookSensitivity")
            }
            if let aim = defaults.object(forKey: "aimSensitivity") as? Double {
                defaults.set(min(15, max(0.2, aim)), forKey: "mouseAimSensitivity")
            }
        }
        defaults.set(true, forKey: "personalRelease3Migrated")
    }
}
