import UIKit

private struct TrainerAction {
    let command: UInt32
    let title: String
    let detail: String
    let badge: String
}

/// Session tools. Requests cross the C bridge; this controller never edits game memory.
final class TrainerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let categories = UISegmentedControl(items: ["Player", "Vehicles", "World"])
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private let status = UILabel()
    private let availability = UILabel()
    private var timer: Timer?
    private var pending: TrainerAction?
    private var pendingSince = Date.distantPast
    private var lastReady = false
    private var lastInvincible = false
    private let actions: [[TrainerAction]] = [
        [.init(command: 1, title: "Health & armor", detail: "Restore the player using the engine's health cheat.", badge: "RESTORE"),
         .init(command: 2, title: "Weapon loadout", detail: "Equip the engine's cheat weapon set and ammunition.", badge: "EQUIP"),
         .init(command: 5, title: "Invincibility", detail: "Toggle the engine's player damage protection.", badge: "TOGGLE"),
         .init(command: 3, title: "Lower wanted level", detail: "Remove one wanted star. Repeat to clear the chase.", badge: "− STAR"),
         .init(command: 4, title: "Raise wanted level", detail: "Add one wanted star and bring the heat.", badge: "+ STAR")],
        [.init(command: 7, title: "Comet", detail: "Sports car. Spawn near the player.", badge: "SPAWN"),
         .init(command: 8, title: "Sanchez", detail: "Dirt bike. Take the road less traveled.", badge: "SPAWN"),
         .init(command: 9, title: "FIB vehicle", detail: "The engine's FIB vehicle cheat.", badge: "SPAWN"),
         .init(command: 10, title: "Annihilator", detail: "Helicopter. Use an open area with room above.", badge: "SPAWN"),
         .init(command: 11, title: "Jetmax", detail: "Speedboat. Spawn near open water.", badge: "SPAWN")],
        [.init(command: 6, title: "Cycle weather", detail: "Move to the next weather type supported by the game.", badge: "CYCLE"),
         .init(command: 12, title: "Dawn", detail: "Set the clock to 06:00.", badge: "06:00"),
         .init(command: 13, title: "High noon", detail: "Set the clock to 12:00.", badge: "12:00"),
         .init(command: 14, title: "Golden hour", detail: "Set the clock to 19:00.", badge: "19:00"),
         .init(command: 15, title: "Midnight", detail: "Set the clock to 00:00.", badge: "00:00")]
    ]
    private var visibleActions: [TrainerAction] { actions[max(0, categories.selectedSegmentIndex)] }

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
        for item in [header, categories, table, status] {
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
            table.topAnchor.constraint(equalTo: categories.bottomAnchor, constant: 12),
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
    @objc private func categoryChanged() { table.reloadData() }
    private func refresh() {
        let ready = PGTrainerReady()
        let invincible = PGTrainerInvincible()
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
                status.text = "Request stopped. Return to free roam and try again."
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
        if ready != lastReady || invincible != lastInvincible {
            lastReady = ready
            lastInvincible = invincible
            table.reloadData()
        }
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { visibleActions.count }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Best used in free roam. The game stays live. Missions, placement and model availability can prevent an action. Cheats can affect achievements this session."
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
        badge.text = action.command == 5 ? (PGTrainerInvincible() ? "ON" : "OFF") : action.badge
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
        cell.accessibilityValue = action.command == 5 ? badge.text : action.detail
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
