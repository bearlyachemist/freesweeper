import Testing
import SweeperKit
@testable import Freesweeper

@MainActor
struct GameSessionTests {
    // MARK: Starting and resuming

    @Test func freshSessionUsesTheChosenBoard() {
        let choice = Difficulty(shape: .square, size: .medium, level: .hard)
        let h = Harness { $0.difficulty = choice }
        #expect(h.session.game.difficulty == choice)
        #expect(h.session.game.status == .ready)
        #expect(h.session.displaySeconds == 0)
    }

    @Test func resumesASavedGameWithItsTime() {
        let h = Harness.started()
        #expect(h.session.game.status == .playing)
        #expect(h.session.clock.elapsed().seconds == 12.5)
        #expect(!h.session.clock.isRunning, "The clock waits for the app to be in front")
        h.session.scenePhaseChanged(.active)
        #expect(h.session.clock.isRunning)
        #expect(h.session.displaySeconds == 12)
    }

    @Test func backgroundingPausesAndSaves() throws {
        let h = Harness.started()
        h.session.scenePhaseChanged(.active)
        h.session.longPress(Coord(x: 5, y: 5))
        h.session.scenePhaseChanged(.background)
        #expect(!h.session.clock.isRunning)
        let saved = try #require(SavedGame.load(from: h.defaults))
        #expect(saved.game.board[Coord(x: 5, y: 5)].state == .flagged)
    }

    // MARK: Playing

    @Test func winningRecordsTheResult() {
        let h = Harness.started()
        h.session.tap(winningTap)
        #expect(h.session.game.status == .won)
        #expect(h.session.face == .won)
        #expect(h.sounds.played.last == .win)
        #expect(!h.session.clock.isRunning)
        let stats = h.stats.stats(for: h.session.statsMode)
        #expect(stats.won == 1 && stats.played == 1)
        #expect((stats.bestTime ?? 0) >= 12.5)
        #expect(h.defaults.data(forKey: "savedGame") == nil, "A finished game isn't kept")
    }

    @Test func losingRecordsTheResult() {
        let h = Harness.started()
        h.session.tap(mineTap)
        #expect(h.session.game.status == .lost(exploded: mineTap))
        #expect(h.session.face == .lost)
        #expect(h.sounds.played.last == .explosion)
        #expect(h.stats.stats(for: h.session.statsMode).played == 1)
        #expect(h.stats.stats(for: h.session.statsMode).won == 0)
    }

    @Test func longPressFlagsAndTappingANumberChords() {
        let h = Harness.started()
        h.session.longPress(mineTap)
        #expect(h.session.game.board[mineTap].state == .flagged)
        #expect(h.session.flagChanges == 1)
        #expect(h.sounds.played == [.flag])
        h.session.tap(cornerNumber)
        #expect(h.session.game.status == .won)
    }

    @Test func flagModeSwapsTapAndLongPress() {
        let h = Harness.started()
        h.session.inputMode = .flag
        h.session.tap(mineTap)
        #expect(h.session.game.board[mineTap].state == .flagged)
        h.session.longPress(winningTap)
        #expect(h.session.game.status == .won)
    }

    @Test func longPressOnARevealedCellDoesNothing() {
        let h = Harness.started()
        h.session.longPress(cornerNumber)
        #expect(h.session.flagChanges == 0)
        #expect(h.sounds.played.isEmpty)
    }

    @Test func mutedSoundsStaySilent() {
        let h = Harness.started { $0.soundEffects = false }
        h.session.longPress(mineTap)
        h.session.tap(cornerNumber)
        #expect(h.session.game.status == .won)
        #expect(h.sounds.played.isEmpty)
    }

    // MARK: Lock

    @Test func lockedBoardIgnoresTapsAndPresses() {
        let h = Harness.started { $0.showLockButton = true }
        h.session.isLocked = true
        #expect(h.session.isInputLocked)
        h.session.tap(winningTap)
        h.session.longPress(Coord(x: 5, y: 5))
        h.session.press(Coord(x: 5, y: 5))
        #expect(h.session.game.status == .playing)
        #expect(h.session.flagChanges == 0)
        #expect(h.session.pressedCells.isEmpty)

        h.session.isLocked = false
        h.session.tap(winningTap)
        #expect(h.session.game.status == .won)
    }

    @Test func hidingTheLockButtonReleasesTheLock() {
        let h = Harness.started { $0.showLockButton = true }
        h.session.isLocked = true
        h.settings.showLockButton = false
        #expect(!h.session.isInputLocked)
        h.session.tap(winningTap)
        #expect(h.session.game.status == .won)
    }

    // MARK: Touch feedback

    @Test func pressPreviewsWhatATapWouldDo() {
        let h = Harness.started()
        h.session.press(Coord(x: 5, y: 5))
        #expect(h.session.pressedCells == [Coord(x: 5, y: 5)])
        #expect(h.session.face == .pressing)

        h.session.press(cornerNumber)
        #expect(h.session.pressedCells.count == 8, "A number previews its hidden neighbours")

        h.session.press(nil)
        #expect(h.session.pressedCells.isEmpty)
        #expect(h.session.face == .normal)

        h.session.inputMode = .flag
        h.session.press(Coord(x: 5, y: 5))
        #expect(h.session.pressedCells.isEmpty, "Flag mode doesn't push cells in")
    }

    // MARK: New games

    @Test func abandoningAStartedGameCountsAsALoss() {
        let h = Harness.started()
        let mode = h.session.statsMode
        let next = Difficulty(shape: .square, size: .small, level: .easy)
        h.session.newGame(next)
        #expect(h.stats.stats(for: mode).played == 1)
        #expect(h.stats.stats(for: mode).won == 0)
        #expect(h.session.game.status == .ready)
        #expect(h.session.game.difficulty == next)
        #expect(h.defaults.data(forKey: "savedGame") == nil)
    }

    @Test func replacingAnUnstartedGameRecordsNothing() {
        let h = Harness()
        h.session.newGame(Difficulty(shape: .rectangle, size: .small, level: .hard))
        #expect(h.stats.modes.isEmpty)
    }

    // MARK: No Guessing

    @Test func modeFollowsTheSwitchUntilTheFirstDig() {
        let h = Harness { $0.noGuessing = true }
        #expect(h.session.statsMode.noGuessing)
        h.settings.noGuessing = false
        #expect(!h.session.statsMode.noGuessing)
    }

    @Test func noGuessFirstTapBuildsASolvableBoard() async {
        let h = Harness { $0.noGuessing = true }
        let start = Coord(x: 6, y: 6)
        h.session.tap(start)
        #expect(h.session.isGenerating)
        #expect(await eventually { !h.session.isGenerating })
        #expect(h.session.isNoGuessBoard)
        #expect(h.session.statsMode.noGuessing)
        #expect(h.session.game.board[start].state == .revealed)
        #expect(NoGuessGenerator.isSolvable(h.session.game.board, from: start))
    }

    @Test func inputIsIgnoredWhileGenerating() {
        let h = denseNoGuessHarness(limit: .seconds(5))
        h.session.tap(Coord(x: 32, y: 32))
        h.session.longPress(Coord(x: 0, y: 0))
        #expect(h.session.flagChanges == 0)
        h.session.newGame(h.settings.difficulty)
    }

    @Test func timeoutReportsUnavailableAndDigsNothing() async {
        let h = denseNoGuessHarness(limit: .milliseconds(200))
        h.session.tap(Coord(x: 32, y: 32))
        #expect(await eventually { h.flow.noGuessUnavailable })
        #expect(!h.session.isGenerating)
        #expect(h.session.game.needsMines)
        #expect(h.session.game.status == .ready)
    }

    @Test func backgroundingCancelsGeneration() async {
        let h = denseNoGuessHarness(limit: .seconds(5))
        h.session.tap(Coord(x: 32, y: 32))
        h.session.scenePhaseChanged(.background)
        #expect(!h.session.isGenerating)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!h.flow.noGuessUnavailable, "A cancelled search isn't reported as a failure")
        #expect(h.session.game.needsMines)
    }

    @Test func newGameCancelsGeneration() async {
        let h = denseNoGuessHarness(limit: .seconds(5))
        h.session.tap(Coord(x: 32, y: 32))
        let next = Difficulty(shape: .square, size: .small, level: .easy)
        h.session.newGame(next)
        #expect(!h.session.isGenerating)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(h.session.game.difficulty == next)
        #expect(h.session.game.needsMines, "The old search can't place mines on the new game")
    }

    /// 64×64 at ~45% mines: No Guessing can't succeed, so it runs until stopped.
    private func denseNoGuessHarness(limit: Duration) -> Harness {
        Harness(noGuessTimeLimit: limit) {
            $0.noGuessing = true
            $0.difficulty = .custom(width: 64, height: 64, mines: 1_850)
        }
    }
}
