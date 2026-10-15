import UIKit

// UI-only simulator harness. The production engine and saved data are never opened here.
@main
final class PreviewApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        PersonalSettingsMigration.run()
        let controller: UIViewController = ProcessInfo.processInfo.arguments.contains("--test-touch-controls")
            ? PreviewTouchController() : PreviewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class PreviewController: UIViewController {
    private let home = LauncherHomeView(frame: .zero)
    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }
    override func viewDidLoad() {
        super.viewDidLoad()
        home.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(home)
        NSLayoutConstraint.activate([
            home.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            home.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            home.topAnchor.constraint(equalTo: view.topAnchor),
            home.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        home.setDetail("Balanced · 60 FPS · 100% resolution", for: .graphics)
        home.setDetail("Swipe camera, sensitivity and aim", for: .controls)
        home.setDetail("Gyro aiming and tilt steering", for: .motion)
        home.setDetail("Downloaded locally", for: .files)
        home.setDetail("Manage your game file server", for: .connection)
        home.downloadLabel.text = "Downloaded locally"
        home.downloadLabel.isHidden = false
        home.playButton.addAction(UIAction { [weak self] _ in self?.showPicker() }, for: .touchUpInside)
        home.openSection = { [weak self] section in self?.showSettings(section) }
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--trainer-") && $0.hasSuffix("preview") }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let navigation = UINavigationController(rootViewController: TrainerViewController())
                LauncherStyle.configure(navigation)
                self.present(navigation, animated: false)
                navigation.view.layoutIfNeeded()
                func segment(in view: UIView) -> UISegmentedControl? {
                    if let control = view as? UISegmentedControl { return control }
                    return view.subviews.compactMap { segment(in: $0) }.first
                }
                let args = ProcessInfo.processInfo.arguments
                if let control = segment(in: navigation.view) {
                    if args.contains("--trainer-powers-preview") { control.selectedSegmentIndex = 1 }
                    if args.contains("--trainer-vehicles-preview") { control.selectedSegmentIndex = 3 }
                    if args.contains("--trainer-world-preview") { control.selectedSegmentIndex = 4 }
                    if args.contains("--trainer-character-preview") { control.selectedSegmentIndex = 2 }
                    control.sendActions(for: .valueChanged)
                }
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--mode-picker") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.showPicker() }
        }
        if ProcessInfo.processInfo.arguments.contains("--loading") { home.setLoading("Preparing game files · 42% · 1.8 GB") }
        for section in [LauncherSection.graphics, .files] {
            if ProcessInfo.processInfo.arguments.contains("--\(section == .files ? "files" : "graphics")") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.showSettings(section) }
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--landscape") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            }
        }
    }
    private func showPicker() {
        let picker = GameModeViewController()
        picker.modalPresentationStyle = .pageSheet
        picker.sheetPresentationController?.detents = [.custom(identifier: .init("modeChooser")) { min(460, $0.maximumDetentValue) }]
        picker.sheetPresentationController?.prefersGrabberVisible = true
        picker.sheetPresentationController?.preferredCornerRadius = 30
        picker.selectedMode = { [weak self] mode in
            self?.home.statusLabel.text = mode == .story ? "Story selected" : "Sandbox selected"
            self?.home.statusLabel.isHidden = false
        }
        present(picker, animated: false)
    }
    private func showSettings(_ section: LauncherSection) {
        guard section != .connection else { return }
        let settings = SettingsViewController(engineRunning: false, initialSection: section)
        settings.editLayout = { [weak settings] in
            let editor = ControlsLayoutEditorController()
            editor.modalPresentationStyle = .fullScreen
            settings?.present(editor, animated: true)
        }
        let navigation = UINavigationController(rootViewController: settings)
        LauncherStyle.configure(navigation)
        navigation.sheetPresentationController?.detents = [.large()]
        navigation.sheetPresentationController?.prefersGrabberVisible = true
        present(navigation, animated: false)
    }
}
