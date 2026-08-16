import AppKit
import ApplicationServices

enum ResizeError: LocalizedError {
    case noPermission
    case noFrontApp
    case noWindow

    var errorDescription: String? {
        switch self {
        case .noPermission: return "Accessibility access not granted"
        case .noFrontApp: return "No frontmost app"
        case .noWindow: return "That app has no resizable window"
        }
    }
}

struct ResizeResult {
    let appName: String
    let requestedPixels: CGSize
    let actualPixels: CGSize

    var exact: Bool {
        abs(actualPixels.width - requestedPixels.width) < 1
            && abs(actualPixels.height - requestedPixels.height) < 1
    }

    var summary: String {
        let got = "\(Int(actualPixels.width.rounded()))×\(Int(actualPixels.height.rounded()))"
        if exact { return "\(appName) → \(got) px" }
        let want = "\(Int(requestedPixels.width))×\(Int(requestedPixels.height))"
        return "\(appName) → \(got) px (app refused \(want))"
    }
}

enum WindowResizer {

    static var hasPermission: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that deep-links to System Settings.
    static func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Window lookup

    private static func frontWindow() throws -> (element: AXUIElement, appName: String) {
        guard hasPermission else { throw ResizeError.noPermission }
        guard let app = NSWorkspace.shared.frontmostApplication else { throw ResizeError.noFrontApp }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?

        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) != .success {
            var windows: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windows) == .success,
                  let list = windows as? [AXUIElement], let first = list.first
            else { throw ResizeError.noWindow }
            value = first
        }
        guard let element = value else { throw ResizeError.noWindow }
        return (element as! AXUIElement, app.localizedName ?? "Window")
    }

    // MARK: - AX geometry
    //
    // Accessibility uses a top-left origin with y growing downward, anchored on the
    // primary screen. NSScreen uses a bottom-left origin with y growing upward.

    private static var primaryTop: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }

    private static func axFrame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success
        else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    private static func setAXFrame(_ window: AXUIElement, _ rect: CGRect) {
        var origin = rect.origin
        var size = rect.size

        // Move first so the window is on the right screen, then size, then move again:
        // apps that clamp against the current screen need the second pass to land exactly.
        if let value = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
    }

    private static func screen(forAXFrame rect: CGRect) -> NSScreen {
        let center = CGPoint(x: rect.midX, y: primaryTop - rect.midY)
        return NSScreen.screens.first { NSMouseInRect(center, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    /// Screen the pointer is on — used for menu hints, before any window is touched.
    static func screenUnderCursor() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    // MARK: - Actions

    @discardableResult
    static func apply(pixels: CGSize, shrinkToFit: Bool) throws -> ResizeResult {
        let target = try frontWindow()
        guard let current = axFrame(of: target.element) else { throw ResizeError.noWindow }

        let screen = screen(forAXFrame: current)
        let scale = screen.backingScaleFactor
        var size = CGSize(width: pixels.width / scale, height: pixels.height / scale)

        let visible = screen.visibleFrame
        if shrinkToFit {
            let factor = min(1, min(visible.width / size.width, visible.height / size.height))
            size = CGSize(width: (size.width * factor).rounded(.down),
                          height: (size.height * factor).rounded(.down))
        }

        setAXFrame(target.element, axRect(centering: size, in: visible))

        let actual = axFrame(of: target.element)?.size ?? size
        return ResizeResult(
            appName: target.appName,
            requestedPixels: CGSize(width: size.width * scale, height: size.height * scale),
            actualPixels: CGSize(width: actual.width * scale, height: actual.height * scale)
        )
    }

    @discardableResult
    static func center() throws -> ResizeResult {
        let target = try frontWindow()
        guard let current = axFrame(of: target.element) else { throw ResizeError.noWindow }

        let screen = screen(forAXFrame: current)
        let scale = screen.backingScaleFactor
        setAXFrame(target.element, axRect(centering: current.size, in: screen.visibleFrame))

        let pixels = CGSize(width: current.width * scale, height: current.height * scale)
        return ResizeResult(appName: target.appName, requestedPixels: pixels, actualPixels: pixels)
    }

    /// Centred in `visible` (Cocoa coords), converted to AX coords.
    /// A window taller than the visible area is pinned to the top so the title bar
    /// stays reachable and the overflow spills past the bottom edge.
    private static func axRect(centering size: CGSize, in visible: CGRect) -> CGRect {
        let x = (visible.midX - size.width / 2).rounded()
        let y = size.height <= visible.height
            ? (visible.midY - size.height / 2).rounded()
            : visible.maxY - size.height
        return CGRect(x: x, y: primaryTop - (y + size.height), width: size.width, height: size.height)
    }
}
