import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSWindowDelegate {
    private let store: AccountProfileStore
    private let statusItem: NSStatusItem
    private var accountWindowController: NSWindowController?

    init(store: AccountProfileStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        observeProfileChanges()
        rebuildMenu()
    }

    func rebuildMenu() {
        store.refresh()

        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(headerItem())
        menu.addItem(.separator())

        if store.profiles.isEmpty {
            menu.addItem(menuItem("Capture Current...", action: #selector(openSettings)))
        } else {
            for profile in store.profiles {
                let item = NSMenuItem()
                item.view = profileRow(for: profile)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(menuItem("Manage Accounts...", action: #selector(openSettings)))
        menu.addItem(menuItem("Quit", action: #selector(quit)))

        self.statusItem.menu = menu
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        button.toolTip = "Codex Account"

        if let image = croppedImage(named: "menuBar", size: NSSize(width: 16, height: 16)) {
            image.isTemplate = false
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            button.title = ""
            button.image = NSImage(systemSymbolName: "person.crop.circle.badge.arrow.forward", accessibilityDescription: "CodexAccount")
        }
    }

    private func observeProfileChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(profilesDidChange),
            name: AccountProfileStore.profilesDidChangeNotification,
            object: store
        )
    }

    @objc private func profilesDidChange() {
        rebuildMenu()
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        return item
    }

    private func headerItem() -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSStackView()
        view.orientation = .vertical
        view.alignment = .leading
        view.spacing = 3
        view.edgeInsets = NSEdgeInsets(top: 9, left: 12, bottom: 8, right: 12)

        let title = NSTextField(labelWithString: "CodexAccount")
        title.font = .systemFont(ofSize: 13, weight: .semibold)

        let subtitle = NSTextField(labelWithString: "Active: \(shortTitle(store.activeSummary.displayName))")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor

        let configProfile = NSTextField(labelWithString: "Profile: \(store.activeCodexConfigProfileName ?? "Default")")
        configProfile.font = .systemFont(ofSize: 10)
        configProfile.textColor = .tertiaryLabelColor

        view.addArrangedSubview(title)
        view.addArrangedSubview(subtitle)
        view.addArrangedSubview(configProfile)
        view.setFrameSize(NSSize(width: 304, height: 62))
        item.view = view
        return item
    }

    private func profileRow(for profile: AccountProfile) -> NSView {
        AccountProfileMenuRow(
            profile: profile,
            email: profile.displayEmail,
            avatar: avatarImage(for: profile, size: NSSize(width: 18, height: 18)),
            isActive: store.isActive(profile)
        ) { [weak self] in
            self?.switchToProfile(profile)
        }
    }

    private func switchToProfile(_ profile: AccountProfile) {
        store.switchToProfile(profile)
        rebuildMenu()
        statusItem.menu?.cancelTracking()
    }

    private func avatarImage(for profile: AccountProfile, size: NSSize) -> NSImage {
        if let avatarURL = store.avatarURL(for: profile),
           let customImage = circularImage(contentsOf: avatarURL, size: size) {
            return customImage
        }

        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        NSBezierPath(ovalIn: rect).addClip()

        let gradient = AccountAvatarPalette.gradients[profile.normalizedAvatarGradientIndex]
        let startColor = NSColor(hex: gradient.startHex) ?? .controlAccentColor
        let endColor = NSColor(hex: gradient.endHex) ?? .systemPink
        NSGradient(starting: startColor, ending: endColor)?.draw(in: rect, angle: 135)

        let initials = profile.displayInitials as NSString
        let fontSize = max(8, size.height * (initials.length > 1 ? 0.42 : 0.52))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.95)
        ]
        let textSize = initials.size(withAttributes: attributes)
        initials.draw(
            at: NSPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2 - 0.5),
            withAttributes: attributes
        )

        image.unlockFocus()
        return image
    }

    private func circularImage(contentsOf url: URL, size: NSSize) -> NSImage? {
        guard let source = NSImage(contentsOf: url) else {
            return nil
        }

        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        NSBezierPath(ovalIn: rect).addClip()
        source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        image.unlockFocus()
        return image
    }

    private func shortTitle(_ title: String) -> String {
        if title.count <= 30 {
            return title
        }

        return String(title.prefix(27)) + "..."
    }

    @objc private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let window = accountWindowController?.window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let content = SettingsView(store: store)
            .frame(minWidth: 620, minHeight: 460)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CodexAccount"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: content)
        let controller = NSWindowController(window: window)
        accountWindowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func croppedImage(named name: String, size: NSSize) -> NSImage? {
        guard let source = Bundle.main.url(forResource: name, withExtension: "png")
            .flatMap(NSImage.init(contentsOf:)),
              let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let cropped = cropTransparentPixels(from: bitmap) else {
            source.size = size
            return source
        }

        let image = NSImage(size: size)
        image.lockFocus()
        NSImage(cgImage: cropped, size: size).draw(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func cropTransparentPixels(from bitmap: NSBitmapImageRep) -> CGImage? {
        var minX = bitmap.pixelsWide
        var minY = bitmap.pixelsHigh
        var maxX = -1
        var maxY = -1

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0 > 0.01 else {
                    continue
                }

                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY,
              let cgImage = bitmap.cgImage else {
            return nil
        }

        return cgImage.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6,
              let value = Int(cleaned, radix: 16) else {
            return nil
        }

        self.init(
            calibratedRed: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}

private final class AccountProfileMenuRow: NSView {
    private let action: () -> Void
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { needsDisplay = true }
    }

    init(profile: AccountProfile, email: String?, avatar: NSImage?, isActive: Bool, action: @escaping () -> Void) {
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: 304, height: email == nil ? 38 : 50))
        wantsLayer = true

        let avatarView = NSImageView(image: avatar ?? NSImage())
        avatarView.imageScaling = .scaleProportionallyUpOrDown
        avatarView.wantsLayer = true
        avatarView.layer?.cornerRadius = 9
        avatarView.layer?.masksToBounds = true
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.widthAnchor.constraint(equalToConstant: 18).isActive = true
        avatarView.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let nameLabel = NSTextField(labelWithString: profile.name)
        nameLabel.font = .systemFont(ofSize: 13, weight: isActive ? .semibold : .regular)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail

        let textViews: [NSView]
        if let email {
            let emailLabel = NSTextField(labelWithString: email)
            emailLabel.font = .systemFont(ofSize: 11)
            emailLabel.textColor = .secondaryLabelColor.withAlphaComponent(0.72)
            emailLabel.lineBreakMode = .byTruncatingTail
            textViews = [nameLabel, emailLabel]
        } else {
            textViews = [nameLabel]
        }

        let textStack = NSStackView(views: textViews)
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let checkmark = NSTextField(labelWithString: isActive ? "✓" : "")
        checkmark.font = .systemFont(ofSize: 15, weight: .semibold)
        checkmark.textColor = .labelColor.withAlphaComponent(0.88)
        checkmark.alignment = .center
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.widthAnchor.constraint(equalToConstant: 18).isActive = true

        let rowStack = NSStackView(views: [avatarView, textStack, checkmark])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 14
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            rowStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        action()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isHovered else {
            return
        }

        NSColor.selectedContentBackgroundColor.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 3), xRadius: 7, yRadius: 7).fill()
    }
}
