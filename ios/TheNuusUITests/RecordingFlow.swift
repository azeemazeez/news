import XCTest

/// Drives the full demo flow for the App Review screen recording.
/// Paced with sleeps so the resulting video is watchable at normal speed.
final class RecordingFlow: XCTestCase {

    func testDemoFlow() throws {
        let app = XCUIApplication(bundleIdentifier: "com.thenuus.app")
        app.launch()
        sleep(6) // splash animation + today's edition loading

        // Bring the stories into view.
        app.swipeUp()
        sleep(2)

        // ── Native story reader ──────────────────────────────────────────
        let longText = NSPredicate(format: "label MATCHES %@", "(?s).{120,}")
        let story = app.staticTexts.matching(longText).firstMatch
        XCTAssertTrue(story.waitForExistence(timeout: 5), "no story text on screen")
        story.tap()
        sleep(3)

        // Listen (on-device TTS), then pause.
        let listen = app.buttons["Listen"]
        XCTAssertTrue(listen.waitForExistence(timeout: 5), "reader did not open")
        listen.tap()
        sleep(5)
        app.buttons["Pause"].tap()
        sleep(1)

        // Save the story.
        app.buttons["reader-save"].tap()
        sleep(2)

        // Adjust text size from the reader control.
        app.buttons["Text size"].tap()
        sleep(1)
        app.buttons["Large"].tap()
        sleep(2)

        app.navigationBars.buttons.firstMatch.tap() // back to feed
        sleep(2)

        // ── Context menu (long-press) ────────────────────────────────────
        let secondStory = app.staticTexts.matching(longText).element(boundBy: 1)
        secondStory.press(forDuration: 1.6)
        sleep(3)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.08)).tap()
        sleep(2)

        // ── Archive: native calendar, load a past edition ────────────────
        app.buttons["Menu"].tap()
        sleep(1)
        app.buttons["Archive"].tap()
        sleep(3)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let dayNum = Calendar.current.component(.day, from: yesterday)
        let dayCell = app.datePickers.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "\(dayNum)")).firstMatch
        XCTAssertTrue(dayCell.waitForExistence(timeout: 4), "calendar did not appear")
        dayCell.tap()
        sleep(4) // past edition + banner

        // Pull to refresh back to today.
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        top.press(forDuration: 0.2, thenDragTo: bottom)
        sleep(4)

        // ── Saved stories ────────────────────────────────────────────────
        app.buttons["Menu"].tap()
        sleep(1)
        app.buttons["Saved"].tap()
        sleep(2)

        // Cell 0 is the masthead; saved stories start at index 1.
        let savedRow = app.cells.element(boundBy: 1)
        XCTAssertTrue(savedRow.waitForExistence(timeout: 4), "saved list empty")
        savedRow.tap()
        sleep(3)
        app.navigationBars.buttons.firstMatch.tap() // back to saved list
        sleep(1)
        app.cells.element(boundBy: 1).swipeLeft()
        sleep(1)
        app.buttons["Delete"].firstMatch.tap()
        sleep(2)
        app.navigationBars.buttons.firstMatch.tap() // back to feed
        sleep(2)

        // ── Settings: native controls + permission prompt ────────────────
        app.buttons["Menu"].tap()
        sleep(1)
        app.buttons["Settings"].tap()
        sleep(2)

        app.buttons["Regular"].tap()
        sleep(2)

        app.switches["Daily reminder"].firstMatch.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            sleep(2) // let the permission prompt sit on camera
            allow.tap()
        }
        sleep(3) // reminder time row now visible
        app.navigationBars.buttons.firstMatch.tap() // back to feed
        sleep(2)

        // ── Finale: dark mode (flipped externally on this marker) ────────
        NSLog("DARKMODE_MARKER")
        sleep(5)
        app.swipeUp()
        sleep(4)
        app.swipeDown()
        sleep(5)
    }
}
