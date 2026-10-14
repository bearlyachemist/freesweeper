import SwiftUI

extension View {
    /// Shows "Are you sure you want to reset?" when a restart would end an active streak.
    /// Attach wherever a restart can be requested; `isEnabled` lets a covered screen defer
    /// to the sheet on top of it.
    func confirmsNewGame(isEnabled: Bool = true) -> some View {
        modifier(NewGameConfirmation(isEnabled: isEnabled))
    }
}

private struct NewGameConfirmation: ViewModifier {
    let isEnabled: Bool

    @Environment(GameFlow.self) private var flow

    func body(content: Content) -> some View {
        content.alert(
            "Are you sure you want to reset?",
            // Buttons clear the request themselves, so dismissal needs no setter.
            isPresented: Binding(get: { isEnabled && flow.pendingNewGame != nil }, set: { _ in }),
            presenting: flow.pendingNewGame
        ) { _ in
            Button("Reset", role: .destructive) { flow.confirmNewGame() }
            Button("Keep Playing", role: .cancel) { flow.cancelNewGame() }
        } message: { pending in
            Text(pending.message)
        }
    }
}
