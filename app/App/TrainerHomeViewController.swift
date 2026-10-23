import UIKit

/// Categories keep the in-game tools separate from the long Story cheat list.
final class TrainerHomeViewController: UITableViewController {
    private let runningMode: GameMode?
    var configure: ((SettingsViewController) -> Void)?
    private var categories: [(String, String, String, [Int])] {
        let storyStart = 2 + NativeCheatGroup.all.count
        return [
            ("Player", "Health, weapons, god mode, wanted level and money", "person.fill", [2, 3, 1, storyStart + 1, storyStart + 2]),
            ("Vehicles", "Spawn, repair and clean your ride", "car.fill", [0, 4, 5]),
            ("World", "Time of day and weather", "cloud.sun.fill", [6, 7]),
            ("Story cheats", "The game's original controller cheats", "gamecontroller.fill",
             Array(storyStart..<(storyStart + StoryCheats.all.count)))
        ]
    }

    init(runningMode: GameMode?) {
        self.runningMode = runningMode
        super.init(style: .insetGrouped)
        title = "Trainer"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    override func viewDidLoad() {
        super.viewDidLoad()
        Theme.styleSettingsTable(tableView)
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { categories.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = categories[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = item.0
        content.secondaryText = item.1
        content.image = UIImage(systemName: item.2)
        content.imageProperties.tintColor = Theme.accent
        content.textProperties.color = Theme.text
        content.textProperties.font = Theme.body(17, .semibold)
        content.secondaryTextProperties.color = Theme.secondaryText
        cell.contentConfiguration = content
        cell.backgroundColor = Theme.rowBackground
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Actions run when you return to the game. Disable god mode and never wanted for missions that depend on damage or a police chase."
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = categories[indexPath.row]
        let page = SettingsViewController(engineRunning: true, runningMode: runningMode,
                                          title: item.0, sections: [.cheats], trainerRows: item.3)
        configure?(page)
        navigationController?.pushViewController(page, animated: true)
    }
}
