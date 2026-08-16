import Carbon.HIToolbox
import Foundation

/// A target size expressed in *output pixels* — the resolution the recording ends up at.
/// On a 2x display the window is set to half these numbers in points.
struct Preset {
    let group: String
    let name: String
    let pixels: CGSize
    let keyCode: UInt32
    let keyEquivalent: String

    var label: String { "\(name) · \(Int(pixels.width))×\(Int(pixels.height))" }
}

extension Preset {
    /// ⌃⌥⌘ — unlikely to collide with app shortcuts.
    static let hotkeyModifiers = UInt32(controlKey | optionKey | cmdKey)

    static let all: [Preset] = [
        Preset(group: "Landscape · 16:9", name: "4K UHD", pixels: CGSize(width: 3840, height: 2160),
               keyCode: UInt32(kVK_ANSI_1), keyEquivalent: "1"),
        Preset(group: "Landscape · 16:9", name: "1440p", pixels: CGSize(width: 2560, height: 1440),
               keyCode: UInt32(kVK_ANSI_2), keyEquivalent: "2"),
        Preset(group: "Landscape · 16:9", name: "1080p", pixels: CGSize(width: 1920, height: 1080),
               keyCode: UInt32(kVK_ANSI_3), keyEquivalent: "3"),

        Preset(group: "Vertical · 9:16", name: "1080p", pixels: CGSize(width: 1080, height: 1920),
               keyCode: UInt32(kVK_ANSI_4), keyEquivalent: "4"),
        Preset(group: "Vertical · 9:16", name: "2K QHD", pixels: CGSize(width: 1440, height: 2560),
               keyCode: UInt32(kVK_ANSI_5), keyEquivalent: "5"),
        Preset(group: "Vertical · 9:16", name: "4K UHD", pixels: CGSize(width: 2160, height: 3840),
               keyCode: UInt32(kVK_ANSI_6), keyEquivalent: "6"),
        Preset(group: "Vertical · 9:16", name: "720p", pixels: CGSize(width: 720, height: 1280),
               keyCode: UInt32(kVK_ANSI_9), keyEquivalent: "9"),

        Preset(group: "Square · 1:1", name: "Square", pixels: CGSize(width: 1080, height: 1080),
               keyCode: UInt32(kVK_ANSI_7), keyEquivalent: "7"),
    ]
}
