import UIKit

final class OutfitEditorViewController: UITableViewController {
    private let parts = ["Face", "Mask", "Hair", "Jacket & arms", "Trousers", "Bag", "Shoes", "Accessories", "Undershirt", "Armor", "Decals", "Top", "Hat / helmet", "Glasses", "Ear accessories"]
    private var slot = 3
    private var timer: Timer?
    private var pending: UInt32?
    private var since = Date.distantPast
    private var snapshot: UInt64 = 0
    private var lastReady = false
    private var lastSaved = false
    private let status = UILabel()
    private var baseCommand: UInt32 { slot < 12 ? UInt32(120 + slot * 4) : UInt32(168 + (slot - 12) * 4) }
    private var count: Int { Int((snapshot >> 16) & 65535) }
    private var textureCount: Int { Int((snapshot >> 48) & 65535) }
    private let quick: [(UInt32, String)] = [(116, "Default outfit"), (117, "Random outfit"), (119, "Remove accessories"), (180, "Save current outfit"), (181, "Apply saved outfit")]
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Customize outfit"
        overrideUserInterfaceStyle = .dark
        tableView.backgroundColor = LauncherStyle.background
        tableView.tintColor = LauncherStyle.accent
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 70
        status.text = "Choose a piece, then change its style or colour."
        status.textColor = LauncherStyle.secondary
        status.font = .systemFont(ofSize: 13)
        status.numberOfLines = 0
        status.accessibilityIdentifier = "wardrobe.status"
        status.frame = CGRect(x: 24, y: 0, width: 360, height: 80)
        tableView.tableFooterView = status
        PGTrainerSelectClothingSlot(UInt32(slot))
        refresh()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.refresh() }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate(); timer = nil
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        status.frame.size.width = tableView.bounds.width - 48
    }
    private func refresh() {
        let previousPending = pending
        if pending != nil {
            switch PGTrainerStatus() {
            case 2: status.text = "Handed to game · outfit change"; pending = nil
            case 3, 4: status.text = "This option is unavailable for the current character."; pending = nil
            default:
                if Date().timeIntervalSince(since) > 6 { status.text = "Resume free roam, then try again."; pending = nil }
            }
        }
        let updated = PGTrainerClothingState(UInt32(slot))
        let ready = PGTrainerReady(), saved = PGTrainerCommandAvailable(181)
        if updated != snapshot || previousPending != pending || ready != lastReady || saved != lastSaved {
            snapshot = updated; lastReady = ready; lastSaved = saved; tableView.reloadData()
        }
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 1 : section == 1 ? 4 : quick.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { ["Clothing piece", "Styles & colours", "Your look"][section] }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 ? "Available choices come from this character’s wardrobe. Some pieces have only one style or colour." : section == 2 ? "Saved outfits last for this session and can be applied to the same character model. Default outfit restores the model’s original clothing." : nil
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = LauncherStyle.surface
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = LauncherStyle.secondary
        cell.detailTextLabel?.numberOfLines = 0
        if indexPath.section == 0 {
            cell.textLabel?.text = "Piece"
            let drawable = Int(snapshot & 65535) - 1
            let texture = Int((snapshot >> 32) & 65535)
            cell.detailTextLabel?.text = count == 0 ? "No variants available here." : drawable < 0 ? "No accessory · \(count) styles available" : "Style \(drawable + 1)/\(count) · Colour \(texture + 1)/\(max(1, textureCount))"
            let button = UIButton(configuration: .gray())
            button.configuration?.title = parts[slot]
            button.accessibilityIdentifier = "wardrobe.piece"
            button.menu = UIMenu(children: parts.enumerated().map { index, title in
                UIAction(title: title, state: index == slot ? .on : .off) { [weak self] _ in
                    guard let self else { return }
                    self.slot = index
                    PGTrainerSelectClothingSlot(UInt32(index))
                    self.snapshot = PGTrainerClothingState(UInt32(index))
                    self.tableView.reloadData()
                }
            })
            button.showsMenuAsPrimaryAction = true
            button.sizeToFit(); cell.accessoryView = button; cell.selectionStyle = .none
            return cell
        }
        let command = indexPath.section == 1 ? baseCommand + UInt32(indexPath.row) : quick[indexPath.row].0
        cell.textLabel?.text = indexPath.section == 1 ? ["Next style", "Previous style", "Next colour", "Previous colour"][indexPath.row] : quick[indexPath.row].1
        cell.accessibilityIdentifier = indexPath.section == 1 ? "wardrobe.variant.\(indexPath.row)" : "wardrobe.action.\(command)"
        cell.isAccessibilityElement = true
        cell.accessibilityTraits = .button
        var enabled = pending == nil && PGTrainerCommandAvailable(command)
        if indexPath.section == 1 { enabled = enabled && (indexPath.row < 2 ? count > (slot < 12 ? 1 : 0) : textureCount > 1) }
        cell.isUserInteractionEnabled = enabled
        cell.contentView.alpha = enabled ? 1 : 0.45
        if !enabled { cell.accessibilityTraits.insert(.notEnabled) }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section > 0, pending == nil else { return }
        let command = indexPath.section == 1 ? baseCommand + UInt32(indexPath.row) : quick[indexPath.row].0
        guard PGTrainerCommandAvailable(command), PGTrainerRequest(command) else { status.text = "This option is unavailable right now."; return }
        pending = command; since = Date(); status.text = "Updating outfit…"
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        tableView.reloadData()
    }
}
