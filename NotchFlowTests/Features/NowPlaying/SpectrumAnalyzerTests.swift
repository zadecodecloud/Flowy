import XCTest
@testable import NotchFlow

final class SpectrumAnalyzerTests: XCTestCase {
    private func sine(_ hz: Float, rate: Float = 48_000) -> [Float] {
        (0..<SpectrumAnalyzer.fftSize).map { sin(2 * .pi * hz * Float($0) / rate) * 0.5 }
    }

    func testBassToneLightsTheFirstBar() {
        let levels = SpectrumAnalyzer(sampleRate: 48_000).bands(of: sine(100))
        XCTAssertEqual(levels.firstIndex(of: levels.max()!), 0)
    }

    func testTrebleToneLightsTheFifthBar() {
        let levels = SpectrumAnalyzer(sampleRate: 48_000).bands(of: sine(5_000))
        XCTAssertEqual(levels.firstIndex(of: levels.max()!), 4)
    }

    func testSilenceGivesFlatBars() {
        let levels = SpectrumAnalyzer(sampleRate: 48_000).bands(of: [Float](repeating: 0, count: SpectrumAnalyzer.fftSize))
        XCTAssertEqual(levels, [0, 0, 0, 0, 0, 0])
    }
}
