// SwiftUI environment injection point + convenience modifier for CandidateView.Style.

import SwiftUI

extension EnvironmentValues {
    @Entry var candidateViewStyle: CandidateView.Style = .standard
    /// External keyboard attached and a composition running: the row draws
    /// the hardware slot key beside each candidate of the current page
    /// (`HardwareCandidatePage`).
    @Entry var showsCandidateSlotKeys = false
}

extension View {
    func candidateViewStyle(_ style: CandidateView.Style) -> some View {
        environment(\.candidateViewStyle, style)
    }
}
