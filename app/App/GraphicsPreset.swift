import Foundation

/// Graphics presets. The engine reads quality settings once at boot; only the
/// resolution can change while it runs.
/// Ultra Performance (the Lite mode) sits below Battery (raw value -1, so the saved values of the
/// others stay as they were).
enum GraphicsPreset: Int, CaseIterable {
    case lite = -1, battery = 0, performance = 1, balanced = 2, quality = 3, ultra = 4, extreme = 5, max = 6

    /// Ultra Performance: Battery's options, plus half-size textures and a thinner, shorter-range world
    /// (PG_LITE), for phones whose app limit is about 2-2.5 GB. PG_LITE_PRESET=0 hides it (comparisons).
    static let liteAvailable: Bool = ProcessInfo.processInfo.environment["PG_LITE_PRESET"] != "0"
    /// The presets Settings offers, lowest first.
    static var available: [GraphicsPreset] { allCases.filter { $0 != .lite || liteAvailable } }

    var title: String { ["Performance mode", AppLanguage.choose("Battery"), AppLanguage.choose("Performance"), AppLanguage.choose("Balanced"), AppLanguage.choose("Quality"), AppLanguage.choose("Ultra"), "Extreme", AppLanguage.choose("Max")][rawValue + 1] }
    /// Render height in pixels; width follows the screen's shape.
    var height: Int { [360, 432, 540, 720, 900, 1080, 720, 1290][rawValue + 1] }
    var detail: String {
        [AppLanguage.choose("Targets 30 FPS at 360p with sparse traffic, reduced textures and shorter draw distance. Experimental on 2–3 GB devices."),
         AppLanguage.choose("Lowest load, longest play time"), AppLanguage.choose("Lower GPU load with standard world detail"), AppLanguage.choose("Sharper image and shadows"),
         AppLanguage.choose("Higher detail textures, effects and draw distance"), AppLanguage.choose("1080p with high shaders, shadows and reflections"),
         "High-detail 720p; memory use stays within the iOS allowance",
         AppLanguage.choose("Near-native resolution, high textures and full draw distance (newest Pro phones)")][rawValue + 1]
    }

    /// Engine command-line options. Shader quality never goes below 1 (the
    /// low shader set is mostly missing), and tessellation, MSAA and depth of
    /// field stay off because their shaders do not run on Metal here.
    var engineOptions: [String] {
        switch self {
        case .lite, .battery, .performance:
            return ["-shaderQuality=1", "-textureQuality=0", "-shadowQuality=-1", "-reflectionQuality=0", "-particleQuality=0",
                    "-grassQuality=0", "-cityDensity=0", "-lodScale=0", "-pedLodBias=0", "-vehicleLodBias=0", "-pedVariety=0", "-vehicleVariety=0"]
        case .balanced:
            return ["-shaderQuality=1", "-textureQuality=0", "-shadowQuality=0", "-reflectionQuality=0", "-particleQuality=0",
                    "-grassQuality=0", "-cityDensity=0.2", "-lodScale=0.2", "-pedLodBias=0", "-vehicleLodBias=0", "-pedVariety=0.2", "-vehicleVariety=0.2"]
        case .quality:
            return ["-shaderQuality=1", "-textureQuality=1", "-shadowQuality=0", "-reflectionQuality=1", "-particleQuality=1",
                    "-grassQuality=1", "-cityDensity=0.4", "-lodScale=0.4", "-pedLodBias=0.2", "-vehicleLodBias=0.2", "-pedVariety=0.4", "-vehicleVariety=0.4"]
        case .ultra:
            return ["-shaderQuality=2", "-textureQuality=1", "-shadowQuality=1", "-reflectionQuality=2", "-particleQuality=1",
                    "-grassQuality=1", "-cityDensity=0.6", "-lodScale=0.6", "-pedLodBias=0.4", "-vehicleLodBias=0.4", "-pedVariety=0.6", "-vehicleVariety=0.6"]
        case .extreme:
            // Spend the 720p savings on world detail, retaining the cheaper
            // working shader/shadow path rather than Ultra's heavier effects.
            return ["-shaderQuality=1", "-textureQuality=1", "-shadowQuality=0", "-reflectionQuality=1", "-particleQuality=1",
                    "-grassQuality=1", "-cityDensity=0.4", "-lodScale=0.6", "-pedLodBias=0.3", "-vehicleLodBias=0.3",
                    "-pedVariety=0.4", "-vehicleVariety=0.4", "-percentageForStreamer=0.80"]
        case .max:
            return ["-shaderQuality=2", "-textureQuality=2", "-shadowQuality=2", "-reflectionQuality=2", "-particleQuality=2",
                    "-grassQuality=2", "-cityDensity=1", "-lodScale=1", "-pedLodBias=0.6", "-vehicleLodBias=0.6", "-pedVariety=0.8", "-vehicleVariety=0.8"]
        }
    }
}
