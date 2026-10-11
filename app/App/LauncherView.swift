import UIKit

enum LauncherSection: String, CaseIterable {
    case graphics = "Graphics"
    case controls = "Controls"
    case motion = "Motion"
    case files = "Game files"
    case connection = "Connection"


}

enum LauncherStyle {
    static let background = UIColor(red: 0.035, green: 0.043, blue: 0.052, alpha: 1)
    static let surface = UIColor(red: 0.085, green: 0.095, blue: 0.11, alpha: 1)
    static let accent = UIColor(red: 1.0, green: 0.55, blue: 0.49, alpha: 1)
    static let secondary = UIColor(white: 0.70, alpha: 1)

    static func configure(_ navigation: UINavigationController) {
        navigation.overrideUserInterfaceStyle = .dark
        navigation.view.tintColor = accent
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance
    }
}

private final class LauncherGradient: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        let gradient = layer as! CAGradientLayer
        gradient.colors = [UIColor.black.withAlphaComponent(0.12).cgColor,
                           LauncherStyle.background.withAlphaComponent(0.45).cgColor,
                           LauncherStyle.background.cgColor]
        gradient.locations = [0, 0.45, 1]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class LauncherSettingRow: UIControl {
    let detail = UILabel()
    var onSelect: (() -> Void)?
    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? UIColor.white.withAlphaComponent(0.055) : .clear }
    }

    init(section: LauncherSection) {
        super.init(frame: .zero)
        backgroundColor = .clear
        let title = UILabel()
        title.text = section.rawValue
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.textColor = .white
        title.adjustsFontForContentSizeCategory = true
        detail.font = .preferredFont(forTextStyle: .subheadline)
        detail.textColor = LauncherStyle.secondary
        detail.adjustsFontForContentSizeCategory = true
        detail.numberOfLines = 2
        let labels = UIStackView(arrangedSubviews: [title, detail])
        labels.axis = .vertical
        labels.spacing = 3

        // Navigation affordance only. No decorative category icons.
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor.white.withAlphaComponent(0.30)
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 7).isActive = true
        let row = UIStackView(arrangedSubviews: [labels, chevron])
        row.spacing = 16
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 74)
        ])
        accessibilityTraits = .button
        isAccessibilityElement = true
        accessibilityLabel = section.rawValue
        accessibilityIdentifier = "launcher.settings.\(section.rawValue)"
        addAction(UIAction { [weak self] _ in self?.onSelect?() }, for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// The launcher is separate from the Metal surface and disappears once the world is ready.
final class LauncherHomeView: UIView {
    let playButton = UIButton(type: .system)
    let downloadLabel = UILabel()
    let statusLabel = UILabel()
    private let loading = UIActivityIndicatorView(style: .medium)
    private let progressLabel = UILabel()
    private let hero = UIView()
    private var heroHeight: NSLayoutConstraint!
    private var rows: [LauncherSection: LauncherSettingRow] = [:]
    var openSection: ((LauncherSection) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        overrideUserInterfaceStyle = .dark
        backgroundColor = LauncherStyle.background
        let artwork = UIImageView(image: UIImage(named: "LauncherArtwork.jpg"))
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        let shade = LauncherGradient()
        for item in [artwork, shade] {
            item.translatesAutoresizingMaskIntoConstraints = false
            addSubview(item)
            NSLayoutConstraint.activate([
                item.leadingAnchor.constraint(equalTo: leadingAnchor),
                item.trailingAnchor.constraint(equalTo: trailingAnchor),
                item.topAnchor.constraint(equalTo: topAnchor),
                item.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.78)
            ])
        }
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        addSubview(scroll)
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(wrapper)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(content)
        let width = content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -44)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            wrapper.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            wrapper.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            wrapper.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            wrapper.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            wrapper.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            content.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 18),
            content.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -30),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: wrapper.leadingAnchor, constant: 22),
            content.trailingAnchor.constraint(lessThanOrEqualTo: wrapper.trailingAnchor, constant: -22),
            content.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 560), width
        ])

        let brand = UILabel()
        brand.text = "Forked by Zenyical"
        brand.font = .systemFont(ofSize: 12, weight: .semibold)
        brand.textColor = .white
        brand.accessibilityTraits = .header
        let title = UILabel()
        title.text = "GTA V MOBILE"
        title.font = .systemFont(ofSize: 36, weight: .bold)
        title.textColor = .white
        title.numberOfLines = 0
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.7
        title.layer.shadowColor = UIColor.black.cgColor
        title.layer.shadowOpacity = 0.4
        title.layer.shadowRadius = 16
        title.layer.shadowOffset = CGSize(width: 0, height: 2)
        let credit = UILabel()
        credit.text = "Original iOS port by kevinerikjs"
        credit.font = .systemFont(ofSize: 12, weight: .medium)
        credit.textColor = LauncherStyle.secondary
        let heroLabels = UIStackView(arrangedSubviews: [title, brand, credit])
        heroLabels.axis = .vertical
        heroLabels.spacing = 8
        heroLabels.translatesAutoresizingMaskIntoConstraints = false
        hero.addSubview(heroLabels)
        heroHeight = hero.heightAnchor.constraint(equalToConstant: 228)
        NSLayoutConstraint.activate([
            heroHeight,
            heroLabels.leadingAnchor.constraint(equalTo: hero.leadingAnchor),
            heroLabels.trailingAnchor.constraint(equalTo: hero.trailingAnchor),
            heroLabels.bottomAnchor.constraint(equalTo: hero.bottomAnchor, constant: -10)
        ])
        content.addArrangedSubview(hero)
        var play = UIButton.Configuration.filled()
        play.title = "Play"
        play.baseBackgroundColor = UIColor(red: 0.97, green: 0.95, blue: 0.93, alpha: 1)
        play.baseForegroundColor = LauncherStyle.background
        play.cornerStyle = .fixed
        play.background.cornerRadius = 16
        play.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 24, bottom: 18, trailing: 24)
        play.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = .systemFont(ofSize: 20, weight: .semibold)
            return result
        }
        playButton.configuration = play
        playButton.accessibilityIdentifier = "launcher.play"
        content.addArrangedSubview(playButton)
        progressLabel.font = .preferredFont(forTextStyle: .subheadline)
        progressLabel.textColor = .white
        progressLabel.numberOfLines = 0
        loading.color = LauncherStyle.accent
        let progress = UIStackView(arrangedSubviews: [loading, progressLabel])
        progress.spacing = 10
        progress.alignment = .center
        progress.isHidden = true
        progress.accessibilityIdentifier = "launcher.progress"
        content.addArrangedSubview(progress)
        downloadLabel.font = .systemFont(ofSize: 13, weight: .medium)
        downloadLabel.textColor = LauncherStyle.secondary
        downloadLabel.numberOfLines = 0
        downloadLabel.isHidden = true
        content.addArrangedSubview(downloadLabel)
        let settings = UILabel()
        settings.text = "PREFERENCES"
        settings.font = .systemFont(ofSize: 11, weight: .semibold)
        settings.textColor = LauncherStyle.secondary
        content.addArrangedSubview(settings)
        content.setCustomSpacing(16, after: playButton)
        let settingsPanel = UIStackView()
        settingsPanel.axis = .vertical
        settingsPanel.spacing = 0
        settingsPanel.backgroundColor = LauncherStyle.surface
        settingsPanel.layer.cornerRadius = 19
        settingsPanel.clipsToBounds = true
        content.addArrangedSubview(settingsPanel)
        for (index, section) in LauncherSection.allCases.enumerated() {
            let row = LauncherSettingRow(section: section)
            row.onSelect = { [weak self] in self?.openSection?(section) }
            rows[section] = row
            settingsPanel.addArrangedSubview(row)
            if index < LauncherSection.allCases.count - 1 {
                let separator = UIView()
                separator.backgroundColor = UIColor.white.withAlphaComponent(0.08)
                separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                settingsPanel.addArrangedSubview(separator)
            }
        }
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = LauncherStyle.secondary
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.isHidden = true
        content.addArrangedSubview(statusLabel)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        let desired: CGFloat = bounds.width > bounds.height ? 105 : min(258, bounds.height * 0.29)
        if heroHeight.constant != desired { heroHeight.constant = desired }
        super.layoutSubviews()
    }

    func setDetail(_ text: String, for section: LauncherSection) {
        rows[section]?.detail.text = text
        rows[section]?.accessibilityValue = text
    }

    func setLoading(_ message: String?) {
        let progress = progressLabel.superview!
        progress.isHidden = message == nil
        progressLabel.text = message
        playButton.isEnabled = message == nil
        playButton.configuration?.title = message == nil ? "Play" : "Starting game"
        for row in rows.values { row.isEnabled = message == nil; row.alpha = message == nil ? 1 : 0.5 }
        if message == nil { loading.stopAnimating() } else { loading.startAnimating() }
    }
}

final class GameModeViewController: UIViewController {
    var selectedMode: ((GameMode) -> Void)?
    private var selectionMade = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = LauncherStyle.background
        overrideUserInterfaceStyle = .dark
        let heading = UILabel()
        heading.text = "How do you want to play?"
        heading.font = .preferredFont(forTextStyle: .title2)
        heading.adjustsFontForContentSizeCategory = true
        heading.textColor = .white
        heading.numberOfLines = 0
        let subtitle = UILabel()
        subtitle.text = "Pick a mode. Your saves stay right here."
        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.textColor = LauncherStyle.secondary
        subtitle.numberOfLines = 0
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let stack = UIStackView(arrangedSubviews: [heading, subtitle])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        for mode in GameMode.allCases {
            var config = UIButton.Configuration.filled()
            config.title = mode == .story ? "Story" : "Sandbox"
            config.subtitle = mode == .story ? "Missions, characters and your saved campaign." : "Free roam. Explore the city with every weapon."
            config.titleAlignment = .leading
            config.titlePadding = 8
            config.baseBackgroundColor = LauncherStyle.surface
            config.baseForegroundColor = .white
            config.cornerStyle = .fixed
            config.background.cornerRadius = 20
            config.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var result = attributes; result.font = .systemFont(ofSize: 21, weight: .bold); return result
            }
            config.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var result = attributes; result.foregroundColor = LauncherStyle.secondary; return result
            }
            let button = UIButton(configuration: config)
            button.contentHorizontalAlignment = .leading
            button.accessibilityIdentifier = mode == .story ? "launcher.story" : "launcher.sandbox"
            button.addAction(UIAction { [weak self] _ in
                guard let self, !self.selectionMade else { return }
                self.selectionMade = true
                let action = self.selectedMode
                self.dismiss(animated: true) { action?(mode) }
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 30),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
    }
}
