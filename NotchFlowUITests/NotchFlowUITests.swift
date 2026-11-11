import XCTest

final class NotchFlowUITests: XCTestCase {
    @MainActor
    func testLockScreenMediaPreviewExpandsAndShowsLyrics() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-lockscreen-preview"]
        app.launch()
        XCTAssertTrue(app.windows["Lock Screen Preview"].waitForExistence(timeout: 10))
        let expand = app.buttons["lockscreen.artwork.expand"]
        guard expand.waitForExistence(timeout: 10) else { XCTFail("Artwork expansion control missing"); return }
        let compact = XCTAttachment(screenshot: app.windows["Lock Screen Preview"].screenshot())
        compact.name = "Lock Screen Compact Preview"
        compact.lifetime = .keepAlways
        add(compact)
        expand.click()
        let lyricsToggle = app.buttons["lockscreen.lyrics.toggle"]
        XCTAssertTrue(lyricsToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(lyricsToggle.value as? String, "artwork")
        XCTAssertFalse(app.buttons["lockscreen.lyric.2"].exists)
        lyricsToggle.click()
        XCTAssertTrue(app.buttons["lockscreen.lyric.2"].waitForExistence(timeout: 10))
        XCTAssertEqual(lyricsToggle.value as? String, "lyrics")
        let capture = XCTAttachment(screenshot: app.windows["Lock Screen Preview"].screenshot())
        capture.name = "Lock Screen Media Preview"
        capture.lifetime = .keepAlways
        add(capture)
        let playPause = app.buttons["lockscreen.playPause"]
        playPause.click()
        XCTAssertEqual(playPause.value as? String, "paused")
        playPause.click()
        XCTAssertEqual(playPause.value as? String, "playing")
        app.buttons["lockscreen.next"].click()
        XCTAssertTrue(app.descendants(matching: .any)["lockscreen.metadata"].waitForExistence(timeout: 5))
        let metadata = app.descendants(matching: .any)["lockscreen.metadata"]
        XCTAssertTrue(((metadata.value as? String) ?? metadata.label).contains("Afterglow"))
        app.buttons["lockscreen.previous"].click()
        XCTAssertTrue(((metadata.value as? String) ?? metadata.label).contains("Blue Hour"))
        lyricsToggle.click()
        XCTAssertEqual(lyricsToggle.value as? String, "artwork")
        XCTAssertFalse(app.buttons["lockscreen.lyric.2"].exists)
        app.buttons["lockscreen.expanded.close"].click()
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        expand.click()
        XCTAssertEqual(lyricsToggle.value as? String, "artwork")
        lyricsToggle.click()
        app.buttons["lockscreen.expanded.close"].click()
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
    }

    @MainActor
    func testApplicationLaunchesInUITestMode() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    @MainActor
    func testSettingsSidebarSearchAndNavigation() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-settings-preview"]
        app.launch()
        let search = app.textFields["settings.sidebar.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "NotchFlow settings"
        capture.lifetime = .keepAlways
        add(capture)
        search.click()
        search.typeText("Pin")
        let battery = app.descendants(matching: .any)["settings.sidebar.battery"]
        XCTAssertTrue(battery.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["settings.sidebar.nowPlaying"].exists)
        battery.click()
        XCTAssertTrue(app.descendants(matching: .any)["settings.tab.battery"].waitForExistence(timeout: 5))
        let batteryCapture = XCTAttachment(screenshot: app.screenshot())
        batteryCapture.name = "NotchFlow battery settings"
        batteryCapture.lifetime = .keepAlways
        add(batteryCapture)
    }

    @MainActor
    func testSettingsLightAppearance() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-settings-preview", "-settings.general.appearance.mode", "light"]
        app.launch()
        XCTAssertTrue(app.textFields["settings.sidebar.search"].waitForExistence(timeout: 10))
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "NotchFlow settings light"
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor
    func testNotchAppearanceCanBeSelected() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-settings-preview", "-settings.root.selection", "general"]
        app.launch()
        let glass = app.radioButtons["Liquid Glass"]
        let black = app.radioButtons.matching(NSPredicate(format: "label == %@ OR label == %@", "Đen", "Black")).firstMatch
        XCTAssertTrue(glass.waitForExistence(timeout: 10))
        XCTAssertTrue(black.exists)
        black.click()
        XCTAssertTrue(black.isSelected || (black.value as? NSNumber)?.intValue == 1 || (black.value as? String) == "1")
        glass.click()
        print("Glass control after click: selected=\(glass.isSelected), value=\(String(describing: glass.value))")
        XCTAssertTrue(glass.isSelected || (glass.value as? NSNumber)?.intValue == 1 || (glass.value as? String) == "1")
    }

    @MainActor
    func testGlassTransparencyControlIsAvailable() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-settings-preview", "-settings.root.selection", "general", "-settings.notch.backgroundStyle", "glass"]
        app.launch()
        let slider = app.sliders["settings.notch.glassTransparency"]
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        XCTAssertTrue(slider.isEnabled)
        let initialValue = String(describing: slider.value)
        slider.adjust(toNormalizedSliderPosition: 0.8)
        XCTAssertNotEqual(String(describing: slider.value), initialValue)
    }
}
