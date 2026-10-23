import UIKit

/// The start screen: background art, the game's title, where the game files are, the mode choice,
/// Play, and the way into Settings and the controls layout. The view controller keeps the logic;
/// this view only lays things out and reports taps.
final class HomeView: UIView {
    enum FilesState { case ready, attention, problem, busy }

    let playButton = Theme.primaryButton(AppLanguage.choose("Play"), symbol: "play.fill")
    let settingsButton = Theme.glassButton(AppLanguage.choose("Settings"), symbol: "gearshape.fill")
    let layoutButton = Theme.glassButton(AppLanguage.choose("Controls layout"), symbol: "hand.tap.fill")
    let preloadLabel = UILabel()
    let controllerLabel = UILabel()
    /// Taps on the game files card.
    var onFiles: (() -> Void)?
    /// A mode card was tapped (index into GameMode.allCases).
    var onMode: ((Int) -> Void)?

    private let filesCard = UIControl()
    private let filesIcon = UIImageView()
    private let filesTitle = UILabel()
    private let filesDetail = UILabel()
    private let filesSpinner = UIActivityIndicatorView(style: .medium)
    private var modeCards: [ModeCard] = []
    private let modeDetail = UILabel()
    private let brandTitle = UILabel()
    private let brandSubtitle = UILabel()
    init(modes: [(title: String, symbol: String)], log: UIView) {
        super.init(frame: .zero)
        pin(Theme.backdrop(image: "StartBackground", darken: 0.25), to: self)

        let icon = UIImageView(image: UIImage(named: "HomeIcon"))
        icon.contentMode = .scaleAspectFit
        icon.layer.cornerRadius = 12
        icon.clipsToBounds = true
        NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 64), icon.heightAnchor.constraint(equalToConstant: 64)])
        brandTitle.text = "GTA V MOBILE"
        brandTitle.font = Theme.display(32, .black)
        brandTitle.textColor = Theme.text
        brandTitle.adjustsFontSizeToFitWidth = true
        brandTitle.minimumScaleFactor = 0.75
        brandSubtitle.text = "Forked by zenyical (original iOS port by: kevinerikjs)"
        brandSubtitle.font = Theme.body(12, .medium)
        brandSubtitle.textColor = Theme.secondaryText
        brandSubtitle.numberOfLines = 0
        let titles = UIStackView(arrangedSubviews: [brandTitle, brandSubtitle])
        titles.axis = .vertical
        titles.spacing = 5
        let header = UIStackView(arrangedSubviews: [icon, titles])
        header.alignment = .center
        header.spacing = 16

        buildFilesCard()
        for (index, mode) in modes.enumerated() {
            let card = ModeCard(title: mode.title, symbol: mode.symbol)
            card.addAction(UIAction { [weak self] _ in self?.onMode?(index) }, for: .touchUpInside)
            modeCards.append(card)
        }
        let choices = UIStackView(arrangedSubviews: modeCards)
        choices.spacing = 12
        choices.distribution = .fillEqually
        modeDetail.font = Theme.body(13)
        modeDetail.textColor = Theme.secondaryText
        modeDetail.numberOfLines = 0
        let label = UILabel()
        label.text = "CHOOSE YOUR GAME"
        label.font = Theme.body(11, .bold)
        label.textColor = Theme.tertiaryText
        for item in [preloadLabel, controllerLabel] {
            item.font = Theme.body(11)
            item.textColor = Theme.tertiaryText
            item.numberOfLines = 0
        }
        preloadLabel.isHidden = true
        controllerLabel.isHidden = true
        playButton.accessibilityIdentifier = "home.play"
        settingsButton.accessibilityIdentifier = "home.settings"
        filesCard.accessibilityIdentifier = "home.files"
        let version = UILabel()
        version.text = Theme.appVersion
        version.textColor = Theme.tertiaryText
        version.font = Theme.body(11, .medium)
        let column = UIStackView(arrangedSubviews: [header, label, choices, modeDetail, playButton, preloadLabel])
        column.axis = .vertical
        column.spacing = 12
        column.setCustomSpacing(24, after: header)
        column.setCustomSpacing(7, after: label)
        column.setCustomSpacing(7, after: choices)
        column.setCustomSpacing(18, after: modeDetail)
        column.setCustomSpacing(18, after: playButton)
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceVertical = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        scroll.addSubview(column)
        let safe = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 26),
            scroll.topAnchor.constraint(equalTo: safe.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            scroll.widthAnchor.constraint(equalTo: safe.widthAnchor, multiplier: 0.52),
            column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 22),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -22),
            column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        let tools = UIStackView(arrangedSubviews: [filesCard, settingsButton, layoutButton, controllerLabel, version])
        tools.axis = .vertical
        tools.spacing = 10
        tools.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tools)
        NSLayoutConstraint.activate([
            tools.leadingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: 26),
            tools.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -20),
            tools.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -22)
        ])
        // Debug output is opt-in and never takes space from the launch controls.
        log.translatesAutoresizingMaskIntoConstraints = false
        addSubview(log)
        NSLayoutConstraint.activate([
            log.leadingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: 24),
            log.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            log.topAnchor.constraint(equalTo: safe.topAnchor, constant: 20),
            log.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -20)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func refreshLanguage() {
        brandTitle.text = "GTA V MOBILE"
        brandSubtitle.text = "Forked by zenyical (original iOS port by: kevinerikjs)"
        playButton.configuration?.title = AppLanguage.choose("Play")
        settingsButton.configuration?.title = AppLanguage.choose("Settings")
        layoutButton.configuration?.title = AppLanguage.choose("Controls layout")
        for (index, card) in modeCards.enumerated() { card.setTitle(GameMode.allCases[index].title) }
    }

    private func buildFilesCard() {
        let panel = Theme.panel(cornerRadius: 16)
        panel.isUserInteractionEnabled = false
        pin(panel, to: filesCard)
        filesIcon.contentMode = .scaleAspectFit
        filesIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        filesIcon.widthAnchor.constraint(equalToConstant: 30).isActive = true
        filesTitle.font = Theme.body(16, .semibold)
        filesTitle.textColor = Theme.text
        filesDetail.font = Theme.body(13)
        filesDetail.textColor = Theme.secondaryText
        filesDetail.numberOfLines = 2
        let texts = UIStackView(arrangedSubviews: [filesTitle, filesDetail])
        texts.axis = .vertical
        texts.spacing = 2
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)))
        chevron.tintColor = Theme.tertiaryText
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        filesSpinner.color = Theme.text
        let iconHolder = UIView()
        for view in [filesIcon, filesSpinner] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            iconHolder.addSubview(view)
            NSLayoutConstraint.activate([view.centerXAnchor.constraint(equalTo: iconHolder.centerXAnchor), view.centerYAnchor.constraint(equalTo: iconHolder.centerYAnchor)])
        }
        iconHolder.widthAnchor.constraint(equalToConstant: 30).isActive = true
        let row = UIStackView(arrangedSubviews: [iconHolder, texts, chevron])
        row.spacing = 12
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        filesCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: filesCard.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: filesCard.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: filesCard.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: filesCard.bottomAnchor, constant: -12)
        ])
        filesCard.accessibilityTraits = .button
        filesCard.isAccessibilityElement = true
        filesCard.addAction(UIAction { [weak self] _ in self?.onFiles?() }, for: .touchUpInside)
        filesCard.addAction(UIAction { [weak self] _ in self?.filesCard.alpha = 0.7 }, for: [.touchDown, .touchDragEnter])
        filesCard.addAction(UIAction { [weak self] _ in self?.filesCard.alpha = 1 }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    /// Shows where the game files are and whether they're ready.
    func setFiles(_ state: FilesState, title: String, detail: String) {
        filesTitle.text = title
        filesDetail.text = detail
        filesDetail.isHidden = detail.isEmpty
        filesSpinner.isHidden = state != .busy
        filesIcon.isHidden = state == .busy
        if state == .busy { filesSpinner.startAnimating() } else { filesSpinner.stopAnimating() }
        let (symbol, color): (String, UIColor) = switch state {
        case .ready: ("checkmark.circle.fill", Theme.ok)
        case .attention: ("folder.badge.plus", Theme.warning)
        case .problem: ("exclamationmark.triangle.fill", Theme.problem)
        case .busy: ("", Theme.text)
        }
        filesIcon.image = symbol.isEmpty ? nil : UIImage(systemName: symbol)
        filesIcon.tintColor = color
        filesCard.accessibilityLabel = AppLanguage.interpolate(AppLanguage.choose("Game files: {arg0}. {arg1}"), [title, detail])
    }

    func setMode(_ index: Int?, detail: String, enabled: Bool) {
        for (i, card) in modeCards.enumerated() { card.isSelected = i == index; card.isEnabled = enabled }
        modeDetail.text = detail
    }

    private func pin(_ view: UIView, to parent: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: parent.leadingAnchor), view.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            view.topAnchor.constraint(equalTo: parent.topAnchor), view.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])
    }
}

/// One of the Story mode / Sandbox cards.
private final class ModeCard: UIControl {
    private let panel = Theme.panel(cornerRadius: 14)
    private let icon = UIImageView()
    private let label = UILabel()

    init(title: String, symbol: String) {
        super.init(frame: .zero)
        panel.isUserInteractionEnabled = false
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)
        icon.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        label.text = title
        label.font = Theme.body(15, .semibold)
        let row = UIStackView(arrangedSubviews: [icon, label])
        row.spacing = 8
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: leadingAnchor), panel.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.topAnchor.constraint(equalTo: topAnchor), panel.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.centerXAnchor.constraint(equalTo: centerXAnchor), row.centerYAnchor.constraint(equalTo: centerYAnchor),
            row.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 10),
            heightAnchor.constraint(equalToConstant: 44)
        ])
        isAccessibilityElement = true
        accessibilityLabel = title
        update()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setTitle(_ title: String) {
        label.text = title
        accessibilityLabel = title
    }

    override var isSelected: Bool { didSet { update() } }
    override var isEnabled: Bool { didSet { update() } }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.75 : 1 } }

    private func update() {
        let color = isSelected ? Theme.accent : Theme.text
        icon.tintColor = color
        label.textColor = isEnabled ? color : Theme.tertiaryText
        panel.layer.borderColor = (isSelected ? Theme.accent : Theme.panelStroke).cgColor
        panel.layer.borderWidth = isSelected ? 2 : 1
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}

private extension UIStackView {
    func addArrangedSubviews(_ views: [UIView]) { views.forEach(addArrangedSubview) }
}
