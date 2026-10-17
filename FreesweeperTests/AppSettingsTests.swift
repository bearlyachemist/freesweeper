import Foundation
import Testing
import SweeperKit
@testable import Freesweeper

@MainActor
struct AppSettingsTests {
    @Test func defaultsWhenNothingIsStored() {
        let settings = AppSettings(defaults: makeDefaults())
        #expect(settings.appearance == .system)
        #expect(settings.themeStyle == .classic)
        #expect(settings.noGuessing == .off)
        #expect(settings.showMinesRemaining && settings.showTimer)
        #expect(!settings.showLockButton)
        #expect(settings.hapticsEnabled && settings.soundEffects && !settings.timerTick)
        #expect(settings.longPressDuration == 0.35)
        #expect(settings.difficulty == Difficulty(shape: .square, size: .small, level: .easy))
    }

    @Test func changesPersist() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.themeStyle = .modern
        settings.appearance = .dark
        settings.noGuessing = .easy
        settings.showTimer = false
        settings.showLockButton = true
        settings.longPressDuration = 0.5
        settings.difficulty = Difficulty(shape: .rectangle, size: .large, level: .hard)

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.themeStyle == .modern)
        #expect(reloaded.appearance == .dark)
        #expect(reloaded.noGuessing == .easy)
        #expect(!reloaded.showTimer)
        #expect(reloaded.showLockButton)
        #expect(reloaded.longPressDuration == 0.5)
        #expect(reloaded.difficulty == Difficulty(shape: .rectangle, size: .large, level: .hard))
    }

    @Test func oldNoGuessingSwitchBecomesHard() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "noGuessing")
        #expect(AppSettings(defaults: defaults).noGuessing == .hard)
        AppSettings(defaults: defaults).noGuessing = .off
        #expect(AppSettings(defaults: defaults).noGuessing == .off)
    }

    @Test func outOfRangeValuesAreClamped() throws {
        let defaults = makeDefaults()
        defaults.set(5.0, forKey: "longPressDuration")
        let huge = Difficulty(width: 500, height: 2, mines: 99_999)
        defaults.set(try JSONEncoder().encode(huge), forKey: "difficulty")

        let settings = AppSettings(defaults: defaults)
        #expect(settings.longPressDuration == AppSettings.longPressRange.upperBound)
        #expect(Difficulty.sizeRange.contains(settings.difficulty.width))
        #expect(Difficulty.sizeRange.contains(settings.difficulty.height))
        #expect(settings.difficulty.mines <= Difficulty.maxMines(width: settings.difficulty.width, height: settings.difficulty.height))
    }

    @Test func unreadableValuesFallBack() {
        let defaults = makeDefaults()
        defaults.set(Data("garbage".utf8), forKey: "difficulty")
        defaults.set("neon", forKey: "themeStyle")
        defaults.set("sepia", forKey: "appearance")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.difficulty == Difficulty(shape: .square, size: .small, level: .easy))
        #expect(settings.themeStyle == .classic)
        #expect(settings.appearance == .system)
    }

    @Test func timerTickNeedsTheTimerOnScreen() {
        let settings = AppSettings(defaults: makeDefaults())
        settings.timerTick = true
        #expect(settings.allowsSound(.tick))
        settings.showTimer = false
        #expect(!settings.allowsSound(.tick))
        settings.showTimer = true
        settings.timerTick = false
        #expect(!settings.allowsSound(.tick))
    }

    @Test func effectsFollowTheSoundSwitch() {
        let settings = AppSettings(defaults: makeDefaults())
        for effect in [SoundEffect.reveal, .flag, .explosion, .win] {
            #expect(settings.allowsSound(effect))
        }
        settings.soundEffects = false
        for effect in [SoundEffect.reveal, .flag, .explosion, .win] {
            #expect(!settings.allowsSound(effect))
        }
    }
}
