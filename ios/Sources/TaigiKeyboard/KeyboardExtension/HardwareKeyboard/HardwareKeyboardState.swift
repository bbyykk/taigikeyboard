// Whether an external keyboard is attached, and whether the on-screen keys should hide for it.

import GameController
import Observation

/// Tracks the external keyboard for the extension.
///
/// Attached means either the system reports a keyboard (`GCKeyboard.coalesced`,
/// which `GameController` keeps current through its connect / disconnect
/// notifications) or a hardware key press has reached `pressesBegan` — the
/// second covers a keyboard the coalesced device misses, and is what a
/// running composition actually needs to know. Without KeyboardKit Pro the
/// connection must be observed here and pushed into `KeyboardContext`
/// ourselves (`references/KeyboardKit-Documentation` external-keyboards
/// article, KK 10.9.4).
@MainActor
@Observable
final class HardwareKeyboardState {
    private(set) var isAttached: Bool
    /// The user asked for the on-screen keys back while a keyboard is still
    /// attached (a Smart Keyboard Folio snapped on but not in use reads as
    /// attached). Cleared when the keyboard goes away.
    var wantsOnScreenKeys = false {
        didSet { if wantsOnScreenKeys != oldValue { onChange?() } }
    }

    /// Runs after either flag changes, so the controller pushes the new
    /// collapse state into KeyboardKit at once rather than on the next key.
    var onChange: (() -> Void)?

    // `nonisolated(unsafe)`: read once more from `deinit`, which is nonisolated;
    // both are set in `init` and never written again.
    nonisolated(unsafe) private let notificationCenter: NotificationCenter
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        isAttached = GCKeyboard.coalesced != nil
        observers = [.GCKeyboardDidConnect, .GCKeyboardDidDisconnect].map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setAttached(GCKeyboard.coalesced != nil) }
            }
        }
    }

    deinit {
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
    }

    /// A hardware key reached the extension: whatever the device list says,
    /// there is a keyboard.
    func noteHardwareKeyPress() {
        if !isAttached { setAttached(true) }
    }

    private func setAttached(_ attached: Bool) {
        guard attached != isAttached else { return }
        isAttached = attached
        if !attached { wantsOnScreenKeys = false }
        onChange?()
    }
}
