import UIKit

/// Graphics and control options. Before launch every change applies on Play;
/// during play only resolution and controls apply live, the rest on restart.
final class SettingsViewController: UITableViewController {
    private let settings = GameSettings.shared
    private let engineRunning: Bool
    private let bootPreset: GraphicsPreset
    /// The mode the running engine started in (nil before Play).
    private let runningMode: GameMode?
    var resolutionChanged: (() -> Void)?
    var controlsChanged: (() -> Void)?
    var targetingChanged: (() -> Void)?
    var gameModeChanged: (() -> Void)?
    var settingsChanged: (() -> Void)?
    private let initialSection: LauncherSection?

    private enum Section: Int, CaseIterable { case mode, graphics, controls, gyro, files, device }
    private var sections: [Section] {
        switch initialSection {
        case .graphics: return [.graphics, .device]
        case .controls: return [.controls]
        case .motion: return [.gyro]
        case .files: return [.files]
        default: return Section.allCases
        }
    }

    private func reload(_ section: Section, animation: UITableView.RowAnimation = .none) {
        guard let index = sections.firstIndex(of: section) else { return }
        tableView.reloadSections(IndexSet(integer: index), with: animation)
    }
    private let preloader = AssetPreloader.shared
    /// Rows shown in the Game files section, rebuilt from the preloader's phase.
    private enum FileRow { case status, start, pause, resume, cancel, remove }
    private var fileRows: [FileRow] = []
    private var fileStateKey = ""
    private var fileMessage: String?

    init(engineRunning: Bool, runningMode: GameMode? = nil, initialSection: LauncherSection? = nil) {
        self.initialSection = initialSection
        self.engineRunning = engineRunning
        self.runningMode = engineRunning ? runningMode : nil
        self.bootPreset = GameSettings.shared.graphicsPreset
        super.init(style: .insetGrouped)
        title = initialSection?.rawValue ?? "Settings"
        modalPresentationStyle = .formSheet
        overrideUserInterfaceStyle = .dark
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        tableView.backgroundColor = LauncherStyle.background
        tableView.tintColor = LauncherStyle.accent
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.08)
        tableView.sectionHeaderTopPadding = 18
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        fileRows = makeFileRows()
        NotificationCenter.default.addObserver(self, selector: #selector(preloadChanged), name: .assetPreloadChanged, object: nil)
        preloader.refresh()
        let arguments = ProcessInfo.processInfo.arguments
        if let i = arguments.firstIndex(of: "--settings-section"), i + 1 < arguments.count,
           arguments[i + 1] == "files", let index = sections.firstIndex(of: .files) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.tableView.scrollToRow(at: IndexPath(row: 0, section: index), at: .top, animated: false)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        settingsChanged?()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .mode: return GameMode.allCases.count
        case .graphics: return settings.tier.allowed.count + 6
        case .controls: return 9
        case .gyro: return (settings.gyroAim == .off ? 1 : 3) + (settings.tiltSteer == .off ? 1 : 2)
        case .files: return fileRows.count
        case .device: return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Game mode", "Graphics", "Touch controls", "Motion", "Game files", "This device"][sections[section].rawValue]
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sections[section] {
        case .mode:
            var text = "Story mode saves stay on this phone between launches. Sandbox keeps its own separate files."
            if let runningMode {
                text = "Changes apply the next time you start the game. " + text
                if settings.gameMode != runningMode { text += " Close and reopen the app to play \(settings.gameMode.title)." }
            }
            return text
        case .graphics:
            var text = "Resolution changes apply right away. "
            text += engineRunning ? "Graphics preset, distance, texture clarity and FPS changes apply next launch." : "Graphics preset, distance, texture clarity and FPS apply on Play."
            if settings.frameRateOption == .fps120 {
                text += " 120 FPS is an experimental high refresh target. The native engine runs unlocked in this mode; actual FPS may be lower and power use may rise."
            }
            if settings.graphicsPreset != bootPreset && engineRunning { text += " Restart needed for \(settings.graphicsPreset.title)." }
            if settings.tier.risky(settings.graphicsPreset) { text += " Presets above the recommended one can run out of memory or overheat on this phone; if a launch fails, the game falls back automatically." }
            if settings.graphicsPreset == .extreme { text += " Extreme starts at 720p and adapts texture and effect settings to the app allowance. This install reports an app limit of \(settings.tier.memoryLimitMB) MB. Its 8 GB streaming ceiling only applies when iOS allows enough memory; it does not reserve or unlock RAM. If the game cannot launch, the existing fallback lowers the preset." }
            text += " Farther detail and texture clarity increase GPU load. Pixel sharpness also depends on resolution scale and the graphics preset."
            return text
        case .controls:
            return "Use Move buttons to save separate layouts for walking, each vehicle type, and menus. Reset in the editor restores every button position. Direct touch look: finger distance controls camera distance, with no stick dead zone or acceleration. Stopping your finger stops the camera. You can also drag from Aim or Fire while holding those actions. Left stick still moves your character."
        case .gyro:
            return "Move the phone to fine-tune your aim; turning your body turns the camera. Tilt steering turns the phone like a steering wheel: Assist adds fine control on top of the touch steering, Tilt to steer replaces it. The straight-ahead angle is however you hold the phone when you get in."
        case .files: return filesFooter()
        case .device: return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .default
        cell.backgroundColor = LauncherStyle.surface
        var content = cell.defaultContentConfiguration()
        content.secondaryTextProperties.color = .secondaryLabel
        let presets = settings.tier.allowed
        switch sections[indexPath.section] {
        case .mode:
            let mode = GameMode.allCases[indexPath.row]
            content.text = mode.title + (mode == runningMode ? " (playing now)" : "")
            content.secondaryText = mode.detail
            cell.accessoryType = settings.gameModeChoice == mode ? .checkmark : .none
        case .graphics:
            if indexPath.row < presets.count {
                let preset = presets[indexPath.row]
                content.text = preset.title + (preset == settings.tier.recommended ? " (recommended)" : "")
                cell.accessibilityIdentifier = "graphics.preset.\(preset.rawValue)"
                content.secondaryText = "\(preset.height)p · " + preset.detail
                if preset == .extreme && preset.resourcePreset(memoryLimitMB: settings.tier.memoryLimitMB) != .extreme {
                    content.secondaryText = "720p · Detail adapts to this install's \(settings.tier.memoryLimitMB) MB allowance"
                }
                cell.accessoryType = preset == settings.graphicsPreset ? .checkmark : .none
                cell.accessibilityValue = preset == settings.graphicsPreset ? "Selected" : nil
            } else {
                let row = indexPath.row - presets.count
                cell.selectionStyle = .none
                if row == 0 {
                    content.text = "Resolution scale \(Int((settings.resolutionScale * 100).rounded()))%"
                    content.secondaryText = currentSizeText()
                    let slider = UISlider()
                    slider.minimumValue = 0.5; slider.maximumValue = 1
                    slider.value = Float(settings.resolutionScale)
                    slider.frame.size.width = 150
                    slider.accessibilityLabel = "Resolution scale"
                    slider.addAction(UIAction { [weak self, weak slider] _ in
                        guard let self, let slider else { return }
                        self.settings.resolutionScale = (Double(slider.value) * 20).rounded() / 20
                        var updated = cell.defaultContentConfiguration()
                        updated.text = "Resolution scale \(Int((self.settings.resolutionScale * 100).rounded()))%"
                        updated.secondaryText = self.currentSizeText()
                        updated.secondaryTextProperties.color = .secondaryLabel
                        cell.contentConfiguration = updated
                    }, for: .valueChanged)
                    slider.addAction(UIAction { [weak self] _ in self?.resolutionChanged?() }, for: [.touchUpInside, .touchUpOutside])
                    cell.accessoryView = slider
                } else if row == 1 {
                    content.text = "Fill the screen"
                    content.secondaryText = "Render at the screen's shape instead of stretching 16:9"
                    cell.accessoryView = toggle(settings.matchScreenShape, label: "Fill the screen") { [weak self] in
                        self?.settings.matchScreenShape = $0; self?.resolutionChanged?(); self?.tableView.reloadData()
                    }
                } else if row == 2 {
                    content.text = "Frame rate"
                    content.secondaryText = "Higher targets need more power and may not be reached"
                    let button = UIButton(configuration: .gray())
                    button.configuration?.title = "\(settings.frameRateOption.rawValue) FPS"
                    button.accessibilityIdentifier = "graphics.fps"
                    button.menu = UIMenu(children: FrameRateOption.allCases.filter { $0.rawValue >= 60 }.map { option in
                        UIAction(title: option.title, state: option == settings.frameRateOption ? .on : .off) { [weak self] _ in
                            self?.settings.frameRateOption = option
                            self?.reload(.graphics)
                        }
                    })
                    button.showsMenuAsPrimaryAction = true
                    button.sizeToFit()
                    cell.accessoryView = button
                } else if row == 3 {
                    content.text = "Sharper textures & models"
                    content.secondaryText = "Finer model detail farther away; higher textures if memory allows."
                    let detail = toggle(settings.sharperWorld, label: "Sharper textures and models") { [weak self] in
                        self?.settings.sharperWorld = $0
                        self?.reload(.graphics)
                    }
                    detail.isEnabled = settings.graphicsPreset.rawValue >= GraphicsPreset.balanced.rawValue
                    cell.accessoryView = detail
                } else {
                    let distance = row == 4
                    content.text = distance ? "View distance" : "Distant texture clarity"
                    content.secondaryText = distance ? "Keep detailed models farther away; Far uses more memory." : "Sharper roads and surfaces at angles; keeps original texture sizes."
                    let button = UIButton(configuration: .gray())
                    button.configuration?.title = distance ? settings.viewDistance.title : settings.textureClarity.title
                    button.accessibilityIdentifier = distance ? "graphics.distance" : "graphics.texture-clarity"
                    if distance {
                        button.menu = UIMenu(children: ViewDistance.allCases.map { option in
                            UIAction(title: option.title, state: option == settings.viewDistance ? .on : .off) { [weak self] _ in
                                self?.settings.viewDistance = option
                                self?.reload(.graphics)
                            }
                        })
                    } else {
                        button.menu = UIMenu(children: TextureClarity.allCases.map { option in
                            UIAction(title: option.title, state: option == settings.textureClarity ? .on : .off) { [weak self] _ in
                                self?.settings.textureClarity = option
                                self?.reload(.graphics)
                            }
                        })
                    }
                    button.showsMenuAsPrimaryAction = true
                    button.sizeToFit()
                    cell.accessoryView = button
                }
            }
        case .controls:
            cell.selectionStyle = .none
            switch indexPath.row {
            case 0:
                cell.accessoryView = slider(settings.lookSensitivity, 0.3, 12, label: "Look speed") { [weak self] in self?.settings.lookSensitivity = $0 }
                content.text = "Swipe look sensitivity"
            case 7:
                cell.accessoryView = slider(settings.drivingLookSensitivity, 0.3, 12, label: "Driving look speed") { [weak self] in self?.settings.drivingLookSensitivity = $0 }
                content.text = "Driving swipe sensitivity"
            case 8:
                content.text = "Move buttons"
                content.secondaryText = "Drag controls into place; layouts save automatically"
                cell.accessibilityIdentifier = "controls.edit-layout"
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            case 6:
                content.text = "Keep driving camera angle"
                content.secondaryText = "Keep your chosen angle after looking around in a vehicle"
                cell.accessoryView = toggle(settings.keepVehicleCameraAngle, label: "Keep driving camera angle") { [weak self] value in
                    self?.settings.keepVehicleCameraAngle = value
                    PGSetVehicleCameraHold(value)
                }
            case 5:
                cell.accessoryView = slider(settings.aimSensitivity, 0.3, 12, label: "Aim look speed") { [weak self] in self?.settings.aimSensitivity = $0 }
                content.text = "Aim swipe sensitivity"
            case 1:
                cell.accessoryView = slider(settings.controlScale, 0.7, 1.5, label: "Button size") { [weak self] in self?.settings.controlScale = $0; self?.controlsChanged?() }
                content.text = "Button size"
            case 2:
                cell.accessoryView = slider(settings.controlOpacity, 0.2, 1, label: "Button opacity") { [weak self] in self?.settings.controlOpacity = $0; self?.controlsChanged?() }
                content.text = "Button opacity"
            case 3:
                content.text = "Targeting"
                let button = UIButton(configuration: .gray())
                button.configuration?.title = GameSettings.targetingTitles[settings.targetingMode]
                button.menu = UIMenu(children: GameSettings.targetingTitles.enumerated().map { index, title in
                    UIAction(title: title, state: index == settings.targetingMode ? .on : .off) { [weak self] _ in
                        self?.settings.targetingMode = index
                        self?.targetingChanged?()
                        self?.reload(.controls)
                    }
                })
                button.showsMenuAsPrimaryAction = true
                button.sizeToFit()
                cell.accessoryView = button
            default:
                content.text = "Fire also aims"
                content.secondaryText = "Fire locks on first, like the classic mobile GTA games"
                cell.accessoryView = toggle(settings.fireAlsoAims, label: "Fire also aims") { [weak self] in self?.settings.fireAlsoAims = $0 }
            }
        case .gyro:
            let aimRows = settings.gyroAim == .off ? 1 : 3
            if indexPath.row == aimRows {
                content.text = "Tilt steering"
                let button = UIButton(configuration: .gray())
                button.configuration?.title = settings.tiltSteer.title
                button.menu = UIMenu(children: TiltSteerMode.allCases.map { mode in
                    UIAction(title: mode.title, state: mode == settings.tiltSteer ? .on : .off) { [weak self] _ in
                        self?.settings.tiltSteer = mode; self?.reload(.gyro, animation: .automatic)
                    }
                })
                button.showsMenuAsPrimaryAction = true
                button.sizeToFit()
                cell.accessoryView = button
                cell.selectionStyle = .none
            } else if indexPath.row == aimRows + 1 {
                content.text = "Full lock at \(Int(settings.tiltFullLock))°"
                cell.accessoryView = slider(settings.tiltFullLock, 10, 45, label: "Tilt for full steering") { [weak self] in self?.settings.tiltFullLock = $0.rounded() }
                cell.selectionStyle = .none
            } else if indexPath.row == 0 {
                content.text = "Gyro"
                content.secondaryText = settings.gyroAim.title
                let menu = UIMenu(children: GyroAimMode.allCases.map { mode in
                    UIAction(title: mode.title, state: mode == settings.gyroAim ? .on : .off) { [weak self] _ in
                        self?.settings.gyroAim = mode; self?.reload(.gyro, animation: .automatic)
                    }
                })
                let button = UIButton(configuration: .gray())
                button.configuration?.title = settings.gyroAim.title
                button.menu = menu
                button.showsMenuAsPrimaryAction = true
                button.sizeToFit()
                cell.accessoryView = button
                cell.selectionStyle = .none
            } else if indexPath.row == 1 {
                content.text = String(format: "Sensitivity %.1f×", settings.gyroSensitivity)
                let slider = UISlider()
                slider.minimumValue = 0.2; slider.maximumValue = 3
                slider.value = Float(settings.gyroSensitivity)
                slider.frame.size.width = 150
                slider.accessibilityLabel = "Gyro sensitivity"
                slider.addAction(UIAction { [weak self, weak slider] _ in
                    guard let self, let slider else { return }
                    self.settings.gyroSensitivity = (Double(slider.value) * 10).rounded() / 10
                    var updated = cell.defaultContentConfiguration()
                    updated.text = String(format: "Sensitivity %.1f×", self.settings.gyroSensitivity)
                    cell.contentConfiguration = updated
                }, for: .valueChanged)
                cell.accessoryView = slider
                cell.selectionStyle = .none
            } else {
                content.text = "Invert vertical"
                cell.accessoryView = toggle(settings.gyroInvertY, label: "Invert vertical gyro") { [weak self] in self?.settings.gyroInvertY = $0 }
                cell.selectionStyle = .none
            }
        case .files:
            configureFileCell(cell, &content, fileRows[indexPath.row])
        case .device:
            content.text = settings.tier.summary
            content.textProperties.font = .preferredFont(forTextStyle: .footnote)
            content.textProperties.color = .secondaryLabel
            cell.selectionStyle = .none
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if sections[indexPath.section] == .mode {
            settings.gameMode = GameMode.allCases[indexPath.row]
            gameModeChanged?()
            reload(.mode)
            return
        }
        if sections[indexPath.section] == .files { selectFileRow(fileRows[indexPath.row]); return }
        if sections[indexPath.section] == .controls, indexPath.row == 8 {
            let editor = TouchLayoutViewController()
            editor.modalPresentationStyle = .fullScreen
            editor.layoutChanged = { [weak self] in self?.controlsChanged?() }
            present(editor, animated: true)
            return
        }
        let presets = settings.tier.allowed
        guard sections[indexPath.section] == .graphics, indexPath.row < presets.count else { return }
        settings.graphicsPreset = presets[indexPath.row]
        if settings.graphicsPreset == .extreme { settings.resolutionScale = 1.0 }
        resolutionChanged?()
        reload(.graphics)
    }

    // MARK: Game files

    private func makeFileRows() -> [FileRow] {
        let phase = preloader.phase
        let hasFiles = preloader.cachedBytes > 0
        switch phase {
        case .unavailable: return [.status]
        case .idle: return hasFiles ? [.start, .remove] : [.start]
        case .downloading: return [.status, .pause, .cancel]
        case .paused: return [.status, .resume, .cancel] + (hasFiles ? [.remove] : [])
        case .complete: return [.status, .remove]
        }
    }

    @objc private func preloadChanged() {
        let rows = makeFileRows()
        guard let section = sections.firstIndex(of: .files) else { return }
        // Footer text depends on these; a footer only resizes on a reload.
        let key = "\(rows)|\(preloader.phase)|\(preloader.removing)|\(preloader.lastError ?? "")|\(fileMessage ?? "")|\(preloader.measured)|\(preloader.cachedBytes > 0)"
        if rows != fileRows || key != fileStateKey {
            fileRows = rows
            fileStateKey = key
            UIView.performWithoutAnimation { tableView.reloadSections([section], with: .none) }
            return
        }
        // Same rows: refresh the visible text in place (no flicker).
        for (row, kind) in rows.enumerated() {
            guard let cell = tableView.cellForRow(at: IndexPath(row: row, section: section)) else { continue }
            var content = cell.defaultContentConfiguration()
            content.secondaryTextProperties.color = .secondaryLabel
            configureFileCell(cell, &content, kind)
            cell.contentConfiguration = content
        }
    }

    private func progressText() -> String {
        let percent = Int((preloader.fraction * 100).rounded(.down))
        var text = "\(percent)% · \(AssetPreloader.format(preloader.cachedBytes)) of \(AssetPreloader.format(preloader.totalBytes))"
        if preloader.phase == .downloading {
            if let rate = preloader.bytesPerSecond { text += " · \(AssetPreloader.format(UInt64(rate)))/s" }
            if let seconds = preloader.secondsRemaining { text += " · " + AssetPreloader.formatDuration(seconds) }
        }
        return text
    }

    private func configureFileCell(_ cell: UITableViewCell, _ content: inout UIListContentConfiguration, _ row: FileRow) {
        let total = preloader.measured ? AssetPreloader.format(preloader.totalBytes) : "Checking size"
        switch row {
        case .status:
            cell.selectionStyle = .none
            switch preloader.phase {
            case .unavailable(let reason):
                content.text = "Download all game files"
                content.secondaryText = reason
                content.textProperties.color = .secondaryLabel
            case .complete:
                content.text = "Downloaded locally"
                content.secondaryText = "\(total) · plays without streaming"
            case .downloading:
                content.text = "Downloading game files"
                content.secondaryText = progressText()
                cell.accessoryView = progressView()
            default:
                content.text = preloader.lastError == nil ? "Download paused" : "Download stopped"
                content.secondaryText = progressText()
                cell.accessoryView = progressView()
            }
        case .start:
            content.text = "Download all game files"
            content.textProperties.color = .tintColor
            if preloader.cachedBytes > 0 && preloader.measured {
                content.secondaryText = "\(total) · \(AssetPreloader.format(preloader.cachedBytes)) already on this iPhone"
            } else {
                content.secondaryText = total
            }

        case .pause:
            content.text = "Pause"
            content.textProperties.color = .tintColor

        case .resume:
            content.text = "Resume download"
            content.textProperties.color = .tintColor

        case .cancel:
            content.text = "Cancel download"
            content.secondaryText = "Keeps what is already downloaded"
            content.textProperties.color = .systemRed
        case .remove:
            content.text = preloader.removing ? "Removing files…" : "Remove downloaded files"
            content.secondaryText = engineRunning ? "Available after restarting the app" : "Frees \(AssetPreloader.format(preloader.cachedBytes))"
            content.textProperties.color = engineRunning ? .secondaryLabel : .systemRed
            cell.selectionStyle = engineRunning ? .none : .default
        }
    }

    private func progressView() -> UIProgressView {
        let bar = UIProgressView(progressViewStyle: .default)
        bar.frame.size.width = 110
        bar.progress = Float(preloader.fraction)
        bar.accessibilityLabel = "Download progress"
        return bar
    }

    private func filesFooter() -> String {
        var text = ""
        if let message = fileMessage ?? preloader.lastError { text = message + "\n\n" }
        switch preloader.phase {
        case .unavailable: return text
        case .complete:
            text += "The game reads everything from this iPhone. Removing the files frees the space; the game then streams again."
        default:
            text += "Saves the whole game on this iPhone (\(preloader.measured ? AssetPreloader.format(preloader.totalBytes) : "about 21 GB")) so it no longer streams from the server. Keep your game file server reachable while downloading. Keep the app open: in the background the download pauses after a short while and continues when you come back. You can play while it downloads."
            if preloader.cachedBytes > 0 && preloader.phase != .downloading {
                text += " Removing files also clears the startup set; the next Play prepares it again."
            }
        }
        return text
    }

    private func selectFileRow(_ row: FileRow) {
        fileMessage = nil
        switch row {
        case .status: return
        case .start, .resume:
            let start = { [weak self] in
                guard let self else { return }
                if let message = self.preloader.start() { self.showAlert("Can't download", message) }
            }
            if row == .start {
                let alert = UIAlertController(title: "Download all game files?",
                    message: "This saves \(AssetPreloader.format(preloader.missingBytes)) more on this iPhone (\(AssetPreloader.format(preloader.availableBytes())) free). Stay connected to your game file server over Wi-Fi.",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Download", style: .default) { _ in start() })
                present(alert, animated: true)
            } else { start() }
        case .pause: preloader.pause()
        case .cancel: preloader.cancel()
        case .remove:
            guard !engineRunning else { return }
            let alert = UIAlertController(title: "Remove downloaded files?",
                message: "Frees \(AssetPreloader.format(preloader.cachedBytes)). The game will stream from the server again.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.preloader.removeDownloads { message in
                    if let message { self.showAlert("Can't remove files", message) }
                }
            })
            present(alert, animated: true)
        }
        preloadChanged()
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func currentSizeText() -> String {
        let screen = view.window?.windowScene?.screen.bounds.size ?? UIScreen.main.bounds.size
        let (w, h) = GraphicsConfiguration.size(for: engineRunning ? bootPreset : settings.graphicsPreset, scale: settings.resolutionScale,
                                                screen: screen, matchScreenShape: settings.matchScreenShape)
        return "Renders at \(w)×\(h)"
    }
    private func reloadFooters() {
        UIView.performWithoutAnimation { reload(.graphics) }
    }
    private func slider(_ value: Double, _ low: Float, _ high: Float, label: String, changed: @escaping (Double) -> Void) -> UISlider {
        let control = UISlider()
        control.minimumValue = low; control.maximumValue = high
        control.value = Float(value)
        control.frame.size.width = 160
        control.accessibilityLabel = label
        control.addAction(UIAction { [weak control] _ in changed(Double(control?.value ?? 0)) }, for: .valueChanged)
        return control
    }
    private func toggle(_ on: Bool, label: String, changed: @escaping (Bool) -> Void) -> UISwitch {
        let control = UISwitch()
        control.onTintColor = LauncherStyle.accent
        control.isOn = on
        control.accessibilityLabel = label
        control.addAction(UIAction { [weak control] _ in changed(control?.isOn ?? false) }, for: .valueChanged)
        return control
    }
}
