import SwiftUI

/// ActivityKit animates data updates, not a continuously running timeline.
/// A built-in transition makes each checkpoint update visible in every surface.
struct ActivityMascot: View {
    let state: HuntActivityAttributes.ContentState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var canAnimate: Bool {
        !reduceMotion && !isLuminanceReduced && state.finishedAt == nil
    }

    private var phase: Double {
        canAnimate && state.justCleared ? -.pi / 4 : .pi / 4
    }

    var body: some View {
        ActivityGoose(phase: phase)
            .id(state)
            .transition(canAnimate ? .push(from: .leading) : .identity)
            .animation(canAnimate ? .easeInOut(duration: 0.6) : nil, value: state)
            .clipped()
            .accessibilityHidden(true)
    }
}

#Preview {
    ActivityMascot(state: .searching)
        .frame(width: 120, height: 100)
        .padding()
        .background(.blue)
}
