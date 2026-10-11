import Foundation

enum GraphicsPreset: Int, CaseIterable {
    // Keep persisted values stable when adding presets.
    case battery = 0, performance = 1, balanced = 2, quality = 3, ultra = 4, extreme = 5

    static let displayOrder: [GraphicsPreset] = [.battery, .performance, .extreme, .balanced, .quality, .ultra]
    var title: String { ["Battery", "Performance", "Balanced", "Quality", "Ultra", "Extreme"][rawValue] }
    var height: Int { [432, 540, 720, 900, 1080, 720][rawValue] }
    var processBudgetMB: UInt32 { self == .extreme ? 8192 : 0 }
    var detail: String {
        ["Lowest load, longest play time", "Lower GPU load and memory use", "Sharper image and shadows",
         "Higher detail textures, effects and draw distance", "Highest settings this port supports",
         "High-detail 720p for 12 GB devices; up to 8 GB if iOS permits"][rawValue]
    }

    // Total physical RAM is not the app's Jetsam allowance. Keep 720p while
    // avoiding the high-texture profile when this install has less headroom.
    func resourcePreset(memoryLimitMB: Int) -> GraphicsPreset {
        self == .extreme && memoryLimitMB < 5000 ? .balanced : self
    }

    // Keep unsupported MSAA, tessellation and depth of field disabled.
    var engineOptions: [String] {
        switch self {
        case .battery, .performance:
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
        }
    }
}
