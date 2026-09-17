// Which nine candidates the slot keys address, and where a navigation key lands.

import Foundation

/// The iOS candidate bar is one scrolling row with no pages of its own, so
/// the hardware keys impose them: the page is the nine-cell window the
/// highlight is in, derived from the highlight rather than kept as state —
/// there is nothing to keep in sync when a tap or a fresh fetch moves it.
///
/// Every move clamps and never wraps
/// (`macos/.../Candidates/CandidatePresenter.swift` `navigate`, the D4 rule).
enum HardwareCandidatePage {
    /// Nine, because nine is what the slot keys can name.
    static let size = 9

    /// The first index of the page `selected` is on.
    static func pageStart(selected: Int) -> Int {
        max(selected, 0) / size * size
    }

    /// The index `navigation` moves the highlight to from `selected`, or nil
    /// when there is nowhere to go (the ends of the list, an empty list).
    static func target(
        for navigation: HardwareCandidateNavigation,
        from selected: Int,
        count: Int,
    ) -> Int? {
        guard count > 0 else { return nil }
        let current = min(max(selected, 0), count - 1)
        let step = switch navigation {
        case .previous: -1
        case .next: 1
        case .pageBackward: -size
        case .pageForward: size
        }
        let target = min(max(current + step, 0), count - 1)
        return target == current ? nil : target
    }

    /// The absolute index the `slot`-th key addresses on the page `selected`
    /// is on, or nil for a slot the page does not fill.
    static func candidateIndex(forSlot slot: Int, selected: Int, count: Int) -> Int? {
        guard (0 ..< size).contains(slot) else { return nil }
        let index = pageStart(selected: selected) + slot
        return index < count ? index : nil
    }

    /// The slot key drawn beside the candidate at `index`, or nil when it is
    /// not on the page `selected` is on.
    static func slotLabel(forIndex index: Int, selected: Int) -> String? {
        let slot = index - pageStart(selected: selected)
        guard (0 ..< size).contains(slot) else { return nil }
        return HardwareKeyIntent.slotKeyRow[slot]
    }
}
