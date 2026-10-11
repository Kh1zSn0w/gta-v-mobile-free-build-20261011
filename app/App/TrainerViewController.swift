import UIKit

private struct TrainerAction {
    let command: UInt32
    let title: String
    let detail: String
    let badge: String
}

/// Session tools. Requests cross the C bridge; this controller never edits game memory.
final class TrainerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private let categories = UISegmentedControl(items: ["Player", "Powers", "Vehicles", "World"])
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private let status = UILabel()
    private let availability = UILabel()
    private var timer: Timer?
    private var pending: TrainerAction?
    private var pendingSince = Date.distantPast
    private var lastReady = false
    private var lastInvincible = false
    private let actions: [[TrainerAction]] = [
        [
            .init(command: 1, title: "Health & armor", detail: "Restore health and armor.", badge: "RESTORE"),
            .init(command: 2, title: "Weapon loadout", detail: "Equip weapons and ammunition.", badge: "EQUIP"),
            .init(command: 5, title: "Invincibility", detail: "Protect yourself from damage.", badge: "TOGGLE"),
            .init(command: 26, title: "Clear wanted level", detail: "End the police chase.", badge: "CLEAR"),
            .init(command: 3, title: "Lower wanted level", detail: "Remove one wanted star.", badge: "\u2212 STAR"),
            .init(command: 4, title: "Raise wanted level", detail: "Add one wanted star.", badge: "+ STAR"),
            .init(command: 27, title: "Refill special ability", detail: "Recharge your character’s special ability.", badge: "REFILL"),
            .init(command: 25, title: "Reset powers", detail: "Turn off every trainer power and restore normal movement.", badge: "RESET")
        ],
        [
            .init(command: 16, title: "Super jump", detail: "Leap higher using the normal Jump button.", badge: "TOGGLE"),
            .init(command: 17, title: "Explosive punches", detail: "Make melee hits explosive. Keep your distance from bystanders.", badge: "TOGGLE"),
            .init(command: 18, title: "Explosive bullets", detail: "Explosive impacts. Replaces fire bullets.", badge: "TOGGLE"),
            .init(command: 19, title: "Fire bullets", detail: "Incendiary shots. Replaces explosive bullets.", badge: "TOGGLE"),
            .init(command: 20, title: "Fast sprint", detail: "Run at 1.49× normal speed.", badge: "TOGGLE"),
            .init(command: 21, title: "Fast swim", detail: "Swim at 1.49× normal speed.", badge: "TOGGLE"),
            .init(command: 22, title: "Unlimited stamina", detail: "Keep sprint stamina replenished.", badge: "TOGGLE"),
            .init(command: 23, title: "Never wanted", detail: "Continuously clear your wanted level.", badge: "TOGGLE"),
            .init(command: 24, title: "Hover flight · experimental", detail: "On foot: stick steers, Jump rises, Stealth descends. Suspends in vehicles.", badge: "TOGGLE"),
            .init(command: 29, title: "Sky boost", detail: "Launch upward on foot. Invincibility recommended.", badge: "LAUNCH"),
            .init(command: 30, title: "Moon gravity", detail: "Low gravity for longer jumps and floating vehicles.", badge: "TOGGLE"),
            .init(command: 31, title: "Normal gravity", detail: "Restore standard world gravity.", badge: "RESTORE"),
            .init(command: 25, title: "Reset powers", detail: "Switch all powers off. Flight gravity and movement return to normal.", badge: "RESET")
        ],
        [
            .init(command: 28, title: "Repair current vehicle", detail: "Repair the vehicle you are sitting in.", badge: "REPAIR"),
            .init(command: 7, title: "Comet", detail: "Sports car", badge: "SPAWN"),
            .init(command: 8, title: "Sanchez", detail: "Dirt bike", badge: "SPAWN"),
            .init(command: 9, title: "FIB vehicle", detail: "Emergency vehicle", badge: "SPAWN"),
            .init(command: 10, title: "Annihilator", detail: "Helicopter", badge: "SPAWN"),
            .init(command: 11, title: "Jetmax", detail: "Speedboat", badge: "SPAWN"),
            .init(command: 46, title: "Adder", detail: "Supercar. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 47, title: "Zentorno", detail: "Supercar. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 48, title: "T20", detail: "Supercar. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 49, title: "Osiris", detail: "Supercar. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 50, title: "Entity XF", detail: "Supercar. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 51, title: "Infernus", detail: "Supercar. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 52, title: "Vacca", detail: "Supercar. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 53, title: "Voltic", detail: "Electric sports car. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 54, title: "Cheetah", detail: "Supercar. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 55, title: "Bullet", detail: "Supercar. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 56, title: "Banshee", detail: "Sports car. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 57, title: "Buffalo", detail: "Sports sedan. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 58, title: "Elegy RH8", detail: "Sports car. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 59, title: "Jester", detail: "Sports car. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 60, title: "Massacro", detail: "Sports car. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 61, title: "Sultan", detail: "Sports sedan. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 62, title: "Futo", detail: "Drift coupe. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 63, title: "Sentinel", detail: "Coupe. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 64, title: "Dominator", detail: "Muscle car. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 65, title: "Gauntlet", detail: "Muscle car. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 66, title: "Dukes", detail: "Muscle car. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 67, title: "Sandking XL", detail: "Off-road truck. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 68, title: "Rebel", detail: "Off-road pickup. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 69, title: "Bifta", detail: "Off-road buggy. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 70, title: "Blazer", detail: "Quad bike. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 71, title: "Bati 801", detail: "Sport bike. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 72, title: "Akuma", detail: "Sport bike. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 73, title: "Hakuchou", detail: "Sport bike. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 74, title: "Vader", detail: "Motorcycle. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 75, title: "BMX", detail: "Bicycle. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 76, title: "Police cruiser", detail: "Emergency vehicle. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 77, title: "Ambulance", detail: "Emergency vehicle. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 78, title: "Fire truck", detail: "Emergency vehicle. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 79, title: "Rhino", detail: "Tank. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 80, title: "Buzzard", detail: "Attack helicopter. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 81, title: "Frogger", detail: "Helicopter. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 82, title: "P-996 LAZER", detail: "Fighter jet. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 83, title: "Duster", detail: "Propeller plane. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 84, title: "Mallard", detail: "Stunt plane. Requires its game assets; use open space.", badge: "SPAWN"),
            .init(command: 85, title: "Dinghy", detail: "Boat. Requires its game assets; use open space.", badge: "SPAWN")
        ],
        [
            .init(command: 34, title: "Extra sunny", detail: "Set persistent extra sunny weather.", badge: "SET"),
            .init(command: 35, title: "Clear skies", detail: "Set persistent clear skies weather.", badge: "SET"),
            .init(command: 36, title: "Cloudy", detail: "Set persistent cloudy weather.", badge: "SET"),
            .init(command: 37, title: "Overcast", detail: "Set persistent overcast weather.", badge: "SET"),
            .init(command: 38, title: "Rain", detail: "Set persistent rain weather.", badge: "SET"),
            .init(command: 39, title: "Thunderstorm", detail: "Set persistent thunderstorm weather.", badge: "SET"),
            .init(command: 40, title: "Fog", detail: "Set persistent fog weather.", badge: "SET"),
            .init(command: 41, title: "Smog", detail: "Set persistent smog weather.", badge: "SET"),
            .init(command: 42, title: "Clearing skies", detail: "Set persistent clearing skies weather.", badge: "SET"),
            .init(command: 43, title: "Snow", detail: "Set persistent snow weather.", badge: "SET"),
            .init(command: 44, title: "Blizzard", detail: "Set persistent blizzard weather.", badge: "SET"),
            .init(command: 45, title: "Winter snow", detail: "Set persistent winter snow weather.", badge: "SET"),
            .init(command: 32, title: "Random weather", detail: "Choose a random weather type.", badge: "RANDOM"),
            .init(command: 33, title: "Automatic weather", detail: "Release the trainer weather override.", badge: "AUTO"),
            .init(command: 6, title: "Cycle weather", detail: "Advance to the next supported weather type.", badge: "CYCLE"),
            .init(command: 12, title: "Dawn", detail: "Set the clock to 06:00.", badge: "06:00"),
            .init(command: 13, title: "High noon", detail: "Set the clock to 12:00.", badge: "12:00"),
            .init(command: 14, title: "Golden hour", detail: "Set the clock to 19:00.", badge: "19:00"),
            .init(command: 15, title: "Midnight", detail: "Set the clock to 00:00.", badge: "00:00")
        ]
    ]
    private let search = UISearchBar()
    private var lastToggles: UInt32 = 0
    private var visibleActions: [TrainerAction] {
        let rows = actions[max(0, categories.selectedSegmentIndex)]
        let query = (search.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? rows : rows.filter { ($0.title + " " + $0.detail).localizedCaseInsensitiveContains(query) }
    }
    private func isToggle(_ command: UInt32) -> Bool { command == 5 || (16...24).contains(command) || command == 30 }
    private func toggleOn(_ command: UInt32) -> Bool { command == 5 ? PGTrainerInvincible() : PGTrainerToggleState(command) }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = LauncherStyle.background
        view.tintColor = LauncherStyle.accent
        navigationItem.title = "Trainer"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(close))
        let header = UIStackView()
        header.axis = .vertical
        header.spacing = 8
        let eyebrow = UILabel()
        eyebrow.text = "ZENYICAL / SESSION TOOLS"
        eyebrow.textColor = LauncherStyle.accent
        eyebrow.font = .systemFont(ofSize: 11, weight: .bold)
        let title = UILabel()
        title.text = "Make Los Santos yours."
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.7
        title.textColor = .white
        availability.font = .systemFont(ofSize: 12, weight: .medium)
        availability.textColor = LauncherStyle.secondary
        header.addArrangedSubview(eyebrow)
        header.addArrangedSubview(title)
        header.addArrangedSubview(availability)
        categories.selectedSegmentIndex = 0
        categories.selectedSegmentTintColor = LauncherStyle.accent
        categories.setTitleTextAttributes([.foregroundColor: UIColor.black, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)], for: .selected)
        categories.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        categories.accessibilityIdentifier = "trainer.categories"
        categories.addTarget(self, action: #selector(categoryChanged), for: .valueChanged)
        search.placeholder = "Find a tool or vehicle"
        search.searchBarStyle = .minimal
        search.delegate = self
        search.accessibilityIdentifier = "trainer.search"
        search.searchTextField.textColor = .white
        search.tintColor = LauncherStyle.accent
        table.keyboardDismissMode = .onDrag
        table.backgroundColor = .clear
        table.separatorColor = UIColor.white.withAlphaComponent(0.08)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 82
        table.dataSource = self
        table.delegate = self
        table.contentInset.top = -20
        status.text = "Choose a tool. Changes apply to this game session."
        status.textColor = LauncherStyle.secondary
        status.font = .systemFont(ofSize: 12, weight: .medium)
        status.numberOfLines = 0
        status.accessibilityIdentifier = "trainer.status"
        for item in [header, categories, search, table, status] {
            item.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(item)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            header.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            header.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            categories.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16),
            categories.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            categories.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            categories.heightAnchor.constraint(equalToConstant: 36),
            search.topAnchor.constraint(equalTo: categories.bottomAnchor, constant: 6),
            search.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: -8),
            search.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: 8),
            search.heightAnchor.constraint(equalToConstant: 48),
            table.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 4),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -8),
            status.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            status.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            status.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
        refresh()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.refresh() }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
    @objc private func close() { dismiss(animated: true) }
    @objc private func categoryChanged() { search.text = ""; search.resignFirstResponder(); table.reloadData(); table.setContentOffset(.zero, animated: false) }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { table.reloadData() }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    private func refresh() {
        let ready = PGTrainerReady()
        let invincible = PGTrainerInvincible()
        var toggles: UInt32 = 0
        for command: UInt32 in 16...24 { if PGTrainerToggleState(command) { toggles |= 1 << (command - 16) } }
        if PGTrainerToggleState(30) { toggles |= 1 << 9 }
        availability.text = ready ? "GAME LIVE · Tools available" : "Tools unlock when the player is ready and the game menu is closed."
        availability.numberOfLines = 0
        if let pending {
            switch PGTrainerStatus() {
            case 2:
                status.text = "Handed to game · \(pending.title)"
                status.textColor = LauncherStyle.accent
                self.pending = nil
                table.reloadData()
                UIAccessibility.post(notification: .announcement, argument: status.text)
            case 3, 4:
                status.text = "Unavailable here. Check your vehicle, game assets or free-roam state."
                status.textColor = LauncherStyle.secondary
                self.pending = nil
                table.reloadData()
            default:
                if Date().timeIntervalSince(pendingSince) > 6 {
                    status.text = "The game did not respond. Resume free roam, then reopen the trainer."
                    self.pending = nil
                    table.reloadData()
                }
            }
        }
        if ready != lastReady || invincible != lastInvincible || toggles != lastToggles {
            lastToggles = toggles
            lastReady = ready
            lastInvincible = invincible
            table.reloadData()
        }
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { visibleActions.count }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Session-only tools. Powers reset on death or character change. Vehicle models need included assets and clear space; aircraft need room, boats need water. Snow depends on the game’s weather assets. Cheats can affect achievements."
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let action = visibleActions[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = LauncherStyle.surface
        cell.textLabel?.text = action.title
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cell.detailTextLabel?.text = action.detail
        cell.detailTextLabel?.textColor = LauncherStyle.secondary
        cell.detailTextLabel?.font = .systemFont(ofSize: 12)
        cell.detailTextLabel?.numberOfLines = 0
        cell.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        let badge = UILabel()
        badge.text = isToggle(action.command) ? (toggleOn(action.command) ? "ON" : "OFF") : action.badge
        badge.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        badge.textColor = LauncherStyle.accent
        badge.textAlignment = .center
        badge.backgroundColor = LauncherStyle.accent.withAlphaComponent(0.09)
        badge.layer.cornerRadius = 9
        badge.clipsToBounds = true
        badge.frame = CGRect(x: 0, y: 0, width: 72, height: 30)
        badge.isAccessibilityElement = false
        cell.accessoryView = badge
        cell.accessibilityIdentifier = "trainer.action.\(action.command)"
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = action.title
        cell.accessibilityValue = isToggle(action.command) ? badge.text : action.detail
        cell.accessibilityTraits = .button
        let enabled = PGTrainerReady() && pending == nil
        cell.isUserInteractionEnabled = enabled
        cell.contentView.alpha = enabled ? 1 : 0.45
        badge.alpha = enabled ? 1 : 0.45
        cell.selectionStyle = enabled ? .default : .none
        if !enabled { cell.accessibilityTraits.insert(.notEnabled) }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard pending == nil else { return }
        let action = visibleActions[indexPath.row]
        guard PGTrainerRequest(action.command) else {
            status.text = "Trainer unavailable. Return to free roam and try again."
            status.textColor = LauncherStyle.secondary
            return
        }
        pending = action
        pendingSince = Date()
        status.text = "Sending · \(action.title)"
        status.textColor = LauncherStyle.secondary
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        table.reloadData()
    }
}
