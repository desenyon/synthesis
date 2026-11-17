import Carbon
import Foundation

/// A registered system hotkey needs no input monitoring or Accessibility permission.
/// It is active only while Synthesis runs; no agent or background helper is launched.
final class QuickCaptureShortcut {
  static let signature: OSType = 0x5359_4E51
  static let keyCode = UInt32(kVK_Space)
  static let modifiers = UInt32(controlKey | optionKey)
  private var hotKey: EventHotKeyRef?
  private var handler: EventHandlerRef?
  private let invoke: @MainActor () -> Void

  init(invoke: @escaping @MainActor () -> Void) { self.invoke = invoke }

  func install() -> Bool {
    guard hotKey == nil else { return true }
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let context = Unmanaged.passUnretained(self).toOpaque()
    let handlerResult = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, context in
        guard let event, let context else { return OSStatus(eventNotHandledErr) }
        var identity = EventHotKeyID()
        let result = GetEventParameter(
          event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
          MemoryLayout<EventHotKeyID>.size, nil, &identity)
        guard result == noErr, identity.signature == QuickCaptureShortcut.signature,
          identity.id == 1
        else { return OSStatus(eventNotHandledErr) }
        let shortcut = Unmanaged<QuickCaptureShortcut>.fromOpaque(context).takeUnretainedValue()
        Task { @MainActor in shortcut.invoke() }
        return noErr
      }, 1, &eventType, context, &handler)
    guard handlerResult == noErr else { return false }
    let result = RegisterEventHotKey(
      Self.keyCode, Self.modifiers, EventHotKeyID(signature: Self.signature, id: 1),
      GetApplicationEventTarget(), UInt32(kEventHotKeyExclusive), &hotKey)
    if result != noErr { uninstall() }
    return result == noErr
  }

  private func uninstall() {
    if let hotKey { UnregisterEventHotKey(hotKey) }
    if let handler { RemoveEventHandler(handler) }
    hotKey = nil
    handler = nil
  }

  deinit { uninstall() }
}
