import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        PersonalSettingsMigration.run()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = NativePortViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
