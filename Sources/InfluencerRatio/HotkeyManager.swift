import AppKit
import Carbon.HIToolbox

/// Global hotkeys via Carbon's RegisterEventHotKey — the only API that still works
/// system-wide without an extra input-monitoring grant.
final class HotkeyManager {
    private let signature = OSType(0x494E_5252) // 'INRR'
    private var handlers: [UInt32: () -> Void] = [:]
    private var registered: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?

    func start() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue().handlers[id.id]?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }

    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        handlers[id] = action
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers,
                                         EventHotKeyID(signature: signature, id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr { registered.append(ref) }
    }
}
