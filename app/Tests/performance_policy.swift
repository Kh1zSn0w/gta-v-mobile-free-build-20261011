import UIKit
enum AppLanguage {
    static func choose(_ text: String) -> String { text }
    static func interpolate(_ text: String, _ args: [String]) -> String { text }
}
enum Theme { static let isLite = false }
private var configuredOptions: [String] = []
private var configuredHeight: Int32 = 0
private var configuredFrameLimit: Int32 = 0
private var clarity: UInt32 = 99
func PGSetSharperUpscaling(_ enabled: Int32) {}
func PGSetTextureClarity(_ value: UInt32) { clarity = value }
func PGSetMemoryCap(_ value: Int32) {}
func PGConfigureEngine(_ values: UnsafePointer<UnsafePointer<CChar>?>, _ count: UInt32,
                       _ width: Int32, _ height: Int32, _ frameLimit: Int32) {
    configuredOptions = (0..<Int(count)).compactMap { values[$0].map { String(cString: $0) } }
    configuredHeight = height; configuredFrameLimit = frameLimit
}
@main final class PerformancePolicyDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let settings = GameSettings.shared
        UserDefaults.standard.set(0, forKey: "cameraTouchMode")
        assert(settings.cameraTouchMode == .swipeMouse, "Old stick preference must migrate")
        settings.mouseLookSensitivity = 999
        assert(settings.mouseLookSensitivity == 40)
        settings.mouseAimSensitivity = -9
        assert(settings.mouseAimSensitivity == GameSettings.swipeSensitivityMinimum)
        settings.graphicsPreset = .lite
        settings.renderHeight = 1290
        settings.frameRateCap = 0
        settings.graphicsOverrides = ["textureQuality": "2", "cityDensity": "1", "lodScale": "1"]
        settings.viewDistance = .far
        settings.textureClarity = .high
        settings.smallerEngineHeaps = false
        settings.compressedAlphaTextures = false
        _ = GraphicsConfiguration.apply(settings, screen: CGSize(width: 667, height: 375))
        assert(configuredHeight == 360 && configuredFrameLimit == 2)
        assert(clarity == 0)
        assert(configuredOptions.contains("-textureQuality=0"))
        assert(configuredOptions.contains("-cityDensity=0"))
        assert(configuredOptions.contains("-lodScale=0"))
        assert(String(cString: getenv("PG_SMALL_ENGINE_HEAPS")) == "1")
        assert(String(cString: getenv("PG_ASTC_BC3")) == "1")
        assert(String(cString: getenv("PG_LITE")) == "1")
        assert(String(cString: getenv("PG_LITE_DENSITY")) == "0.15")
        assert(settings.graphicsOverrides["textureQuality"] == "2", "Keep the player's normal settings")
        print("PERFORMANCE POLICY CHECKS PASSED")
        fflush(stdout)
        exit(0)
    }
}
