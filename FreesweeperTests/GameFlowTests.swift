import Testing
import SweeperKit
@testable import Freesweeper

@MainActor
struct GameFlowTests {
    let next = Difficulty(shape: .rectangle, size: .medium, level: .easy)

    @Test func unstartedGameRestartsAtOnceAndSavesTheChoice() {
        let h = Harness()
        #expect(h.flow.requestNewGame(next))
        #expect(h.settings.difficulty == next)
        #expect(h.session.game.difficulty == next)
        #expect(h.flow.pendingNewGame == nil)
    }

    @Test func startingACustomBoardAddsItToRecents() {
        let h = Harness()
        h.flow.requestNewGame(next)
        #expect(h.settings.recentCustomBoards.isEmpty, "Presets aren't recents")
        let custom = Difficulty.custom(width: 30, height: 30, mines: 150)
        h.flow.requestNewGame(custom)
        #expect(h.settings.recentCustomBoards.map(\.difficulty) == [custom])
    }

    @Test func startedGameWithoutAStreakRestartsAtOnce() {
        let h = Harness.started()
        #expect(h.flow.requestNewGame(next))
        #expect(h.session.game.difficulty == next)
    }

    @Test func activeStreakAsksFirst() {
        let h = Harness.started()
        h.stats.record(won: true, time: 5, mode: h.session.statsMode)
        let before = h.session.game.board

        #expect(!h.flow.requestNewGame(next))
        #expect(h.flow.pendingNewGame?.message == "You'll lose your 1-game streak.")
        #expect(h.session.game.board == before, "Nothing changes until confirmed")
        #expect(h.settings.difficulty != next)
    }

    @Test func confirmingResetsAndEndsTheStreak() {
        let h = Harness.started()
        let mode = h.session.statsMode
        h.stats.record(won: true, time: 5, mode: mode)
        h.flow.requestNewGame(next)
        h.flow.confirmNewGame()

        #expect(h.flow.pendingNewGame == nil)
        #expect(h.session.game.difficulty == next)
        #expect(h.settings.difficulty == next)
        #expect(h.stats.stats(for: mode).currentStreak == 0)
        #expect(h.stats.overall.current == 0)
    }

    @Test func cancellingKeepsPlaying() {
        let h = Harness.started()
        h.stats.record(won: true, time: 5, mode: h.session.statsMode)
        h.flow.requestNewGame(next)
        h.flow.cancelNewGame()

        #expect(h.flow.pendingNewGame == nil)
        #expect(h.session.game.status == .playing)
        #expect(h.stats.overall.current == 1)
    }

    @Test func finishedGameShowsTheResultCard() async {
        let h = Harness.started()
        h.session.tap(winningTap)
        #expect(await eventually { h.flow.presentedResult != nil })
        let result = h.flow.presentedResult
        #expect(result?.won == true)
        #expect(result?.overallStreakAfter == 1)

        h.flow.dismissResult()
        #expect(h.flow.presentedResult == nil)
    }

    @Test func playAgainClearsTheCardWithoutAsking() async {
        let h = Harness.started()
        h.session.tap(winningTap)
        #expect(await eventually { h.flow.presentedResult != nil })
        #expect(h.flow.requestNewGame(), "A finished game never needs confirmation")
        #expect(h.flow.presentedResult == nil)
        #expect(h.session.game.status == .ready)
    }

    @Test func pendingMessageNamesBothStreaksWhenTheyDiffer() {
        #expect(PendingNewGame(difficulty: nil, modeStreak: 3, overallStreak: 5).message
            == "You'll lose your 3-game streak on this board and your 5-game overall streak.")
        #expect(PendingNewGame(difficulty: nil, modeStreak: 4, overallStreak: 4).message
            == "You'll lose your 4-game streak.")
        #expect(PendingNewGame(difficulty: nil, modeStreak: 0, overallStreak: 2).message
            == "You'll lose your 2-game streak.")
    }
}
