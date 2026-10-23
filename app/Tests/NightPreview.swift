// Preview models are fixtures; the views below are the shipping UIKit sources.
import UIKit
enum AppLanguage {
    static func choose(_ s: String) -> String { s }
    static func interpolate(_ s: String, _ args: [String]) -> String {
        args.enumerated().reduce(s) { $0.replacingOccurrences(of: "{arg\($1.offset)}", with: $1.element) }
    }
    struct Language { var name = "English" }
    static let current = Language()
}
enum LauncherStyle { static let accent = UIColor(red: 0.56, green: 0.78, blue: 0.75, alpha: 1) }
enum GameMode: CaseIterable { case story, sandbox; var title: String { self == .story ? "Story mode" : "Sandbox" } }
final class GameSettings {
    static let shared = GameSettings()
    struct Preset { let title = "Performance mode" }
    let graphicsPreset = Preset()
    let gameMode = GameMode.sandbox
}
enum ModInstaller { struct Installed { var enabled = true }; static func installed() -> [Installed] { [] } }
struct StoryCheat {}
enum StoryCheats { static let all = [StoryCheat(), StoryCheat()] }
enum NativeCheatGroup { static let all = Array(repeating: 0, count: 6) }
struct SpawnVehicle {}
struct NativeCheatAction {}
final class ModsViewController: UIViewController {}
final class SettingsViewController: UIViewController {
    enum Section: Hashable, CaseIterable { case language, mode, graphics, controls, cheats, files, device }
    var resolutionChanged: (() -> Void)?; var controlsChanged: (() -> Void)?
    var editLayout: (() -> Void)?; var targetingChanged: (() -> Void)?; var gameModeChanged: (() -> Void)?
    var cheatSelected: ((StoryCheat) -> Void)?; var moneyEntered: ((Int32) -> Void)?
    var vehicleSelected: ((SpawnVehicle, Bool) -> Void)?; var nativeCheatSelected: ((NativeCheatAction) -> Void)?
    init(engineRunning: Bool, runningMode: GameMode?, title: String?, sections: Set<Section>, trainerRows: [Int]? = nil) {
        super.init(nibName: nil, bundle: nil); self.title = title
    }
    required init?(coder: NSCoder) { fatalError() }
}
final class NightPreviewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override func viewDidLoad() {
        super.viewDidLoad()
        let home = HomeView(modes: [("Story mode", "book.fill"), ("Sandbox", "map.fill")], log: UIView())
        view = home
        home.setMode(1, detail: "Free roam anywhere on the map with every weapon. No missions.", enabled: true)
        home.setFiles(.ready, title: "Game files ready", detail: "Stored on this iPhone")
        home.controllerLabel.isHidden = true
        home.settingsButton.addAction(UIAction { [weak self] _ in self?.showSettings() }, for: .touchUpInside)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if ProcessInfo.processInfo.arguments.contains("--settings") { self.showSettings() }
            if ProcessInfo.processInfo.arguments.contains("--trainer") {
                let nav = UINavigationController(rootViewController: TrainerHomeViewController(runningMode: .sandbox))
                Theme.styleNavigation(nav); nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: false)
            }
        }
    }
    private func showSettings() {
        let nav = UINavigationController(rootViewController: SettingsHomeViewController(engineRunning: false, runningMode: nil))
        Theme.styleNavigation(nav); nav.modalPresentationStyle = .fullScreen
        present(nav, animated: false)
    }
}
@main final class NightPreviewDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w=UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController=NightPreviewController(); w.makeKeyAndVisible(); window=w
        return true
    }
}
