import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let hotkeys = HotkeyManager()

    private var presetItems: [(item: NSMenuItem, preset: Preset)] = []
    private var statusLineItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var shrinkItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var flashReset: DispatchWorkItem?
    private var didPrompt = false

    private var shrinkToFit: Bool {
        get { UserDefaults.standard.bool(forKey: "shrinkToFit") }
        set { UserDefaults.standard.set(newValue, forKey: "shrinkToFit") }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "aspectratio",
                                           accessibilityDescription: "Influencer Ratio")
        statusItem.button?.imagePosition = .imageLeading

        buildMenu()
        menu.delegate = self
        statusItem.menu = menu

        hotkeys.start()
        for (index, preset) in Preset.all.enumerated() {
            hotkeys.register(id: UInt32(index + 1), keyCode: preset.keyCode,
                             modifiers: Preset.hotkeyModifiers) { [weak self] in
                self?.run { try WindowResizer.apply(pixels: preset.pixels, shrinkToFit: self?.shrinkToFit ?? false) }
            }
        }
        hotkeys.register(id: 99, keyCode: UInt32(kVK_ANSI_0),
                         modifiers: Preset.hotkeyModifiers) { [weak self] in
            self?.run { try WindowResizer.center() }
        }

        if !WindowResizer.hasPermission { promptForPermissionOnce() }
    }

    /// The system prompt is modal and easy to trigger repeatedly from hotkeys.
    /// Show it at most once per launch; after that the menu bar just reports the error.
    private func promptForPermissionOnce() {
        guard !didPrompt else { return }
        didPrompt = true
        WindowResizer.requestPermission()
    }

    // MARK: - Menu

    private func buildMenu() {
        var lastGroup = ""
        for preset in Preset.all {
            if preset.group != lastGroup {
                lastGroup = preset.group
                menu.addItem(header(preset.group))
            }
            let item = NSMenuItem(title: preset.label, action: #selector(applyPreset(_:)),
                                  keyEquivalent: preset.keyEquivalent)
            item.keyEquivalentModifierMask = [.control, .option, .command]
            item.target = self
            item.indentationLevel = 1
            menu.addItem(item)
            presetItems.append((item, preset))
        }

        menu.addItem(.separator())

        let centerItem = NSMenuItem(title: "Center Window", action: #selector(centerWindow), keyEquivalent: "0")
        centerItem.keyEquivalentModifierMask = [.control, .option, .command]
        centerItem.target = self
        menu.addItem(centerItem)

        shrinkItem = NSMenuItem(title: "Shrink to Fit Screen", action: #selector(toggleShrink), keyEquivalent: "")
        shrinkItem.target = self
        menu.addItem(shrinkItem)

        menu.addItem(.separator())

        statusLineItem = header("No window resized yet")
        menu.addItem(statusLineItem)

        permissionItem = NSMenuItem(title: "Grant Accessibility Access…",
                                    action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)

        loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Influencer Ratio",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        return item
    }

    /// Refreshed each time the menu opens: permission state, and which presets
    /// physically fit on the screen the pointer is currently over.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let granted = WindowResizer.hasPermission
        permissionItem.isHidden = granted

        shrinkItem.state = shrinkToFit ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let screen = WindowResizer.screenUnderCursor()
        let scale = screen.backingScaleFactor
        let availablePixels = CGSize(width: screen.visibleFrame.width * scale,
                                     height: screen.visibleFrame.height * scale)

        for (item, preset) in presetItems {
            let fits = preset.pixels.width <= availablePixels.width
                && preset.pixels.height <= availablePixels.height
            item.title = fits || shrinkToFit ? preset.label : "\(preset.label)  ⚠︎"
            item.toolTip = fits
                ? nil
                : "Bigger than the \(Int(availablePixels.width))×\(Int(availablePixels.height)) px usable area — "
                  + (shrinkToFit ? "will be shrunk to fit." : "will overflow past the screen edge.")
        }
    }

    // MARK: - Actions

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let preset = presetItems.first(where: { $0.item === sender })?.preset else { return }
        run { try WindowResizer.apply(pixels: preset.pixels, shrinkToFit: self.shrinkToFit) }
    }

    @objc private func centerWindow() {
        run { try WindowResizer.center() }
    }

    @objc private func toggleShrink() {
        shrinkToFit.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            report("Login item failed: \(error.localizedDescription)")
        }
    }

    @objc private func openAccessibilitySettings() {
        didPrompt = false
        promptForPermissionOnce()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Feedback

    private func run(_ work: () throws -> ResizeResult) {
        do {
            report(try work().summary)
        } catch {
            report(error.localizedDescription)
            if case ResizeError.noPermission = error { promptForPermissionOnce() }
        }
    }

    /// Flashes the outcome in the menu bar and keeps it in the menu as the last result.
    private func report(_ message: String) {
        statusLineItem.attributedTitle = NSAttributedString(string: message, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])

        flashReset?.cancel()
        statusItem.button?.title = " \(message)"
        let reset = DispatchWorkItem { [weak self] in self?.statusItem.button?.title = "" }
        flashReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: reset)
    }
}
