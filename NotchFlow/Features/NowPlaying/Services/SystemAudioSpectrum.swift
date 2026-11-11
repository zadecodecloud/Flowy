internal import AppKit
import AudioToolbox
import CoreAudio
import Accelerate
import OSLog

/// Live loudness of six frequency bands of the sound the Mac is playing, for the music bars.
///
/// It taps the system output with a Core Audio process tap (macOS 14.2+), which asks once for
/// "System Audio Recording". Nothing is recorded or kept: each block of samples is reduced to
/// six numbers and dropped. Views call `retain()` while they show the bars and `release()`
/// after, so the tap only runs while bars are visible. Without permission the tap delivers
/// silence, `isLive` stays false and the bars keep their built-in animation.
final class SystemAudioSpectrum {
    static let shared = SystemAudioSpectrum()
    static let bandCount = 6

    private(set) var levels = [Float](repeating: 0, count: SystemAudioSpectrum.bandCount)
    /// True while non-silent audio arrived in the last moment.
    private(set) var isLive = false

    private var observers: [UUID: () -> Void] = [:]
    private var users = 0
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var analyzer: SpectrumAnalyzer?
    private var lastSound: TimeInterval = 0
    private let ioQueue = DispatchQueue(label: "app.notchflow.spectrum", qos: .userInteractive)
    private let log = Logger(subsystem: "app.notchflow.mac", category: "spectrum")

    /// Calls `onChange` on the main thread at most ≈ 30 times a second.
    func observe(_ onChange: @escaping () -> Void) -> UUID {
        let id = UUID()
        observers[id] = onChange
        retain()
        return id
    }

    func removeObserver(_ id: UUID) {
        guard observers.removeValue(forKey: id) != nil else { return }
        release()
    }

    private func retain() {
        users += 1
        if users == 1 { start() }
    }

    private func release() {
        users = max(0, users - 1)
        if users == 0 { stop() }
    }

    // MARK: - Tap

    private func start() {
        guard tapID == kAudioObjectUnknown else { return }
        log.info("Starting the system audio tap")
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted
        var tap = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateProcessTap(description, &tap) == noErr else {
            log.error("Could not create the audio tap")
            return
        }
        tapID = tap

        var aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Flowy Music Bars",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: description.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true
            ]]
        ]
        if let outputUID = Self.defaultOutputUID() {
            aggregateDescription[kAudioAggregateDeviceMainSubDeviceKey] = outputUID
            aggregateDescription[kAudioAggregateDeviceSubDeviceListKey] = [[kAudioSubDeviceUIDKey: outputUID]]
        }
        var aggregate = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &aggregate) == noErr else {
            log.error("Could not create the aggregate device")
            stop()
            return
        }
        aggregateID = aggregate

        let format = Self.tapFormat(tap)
        let analyzer = SpectrumAnalyzer(sampleRate: Float(format?.mSampleRate ?? 48_000))
        self.analyzer = analyzer
        var proc: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&proc, aggregate, ioQueue) { [weak self] _, input, _, _, _ in
            guard let bands = analyzer.process(input) else { return }
            DispatchQueue.main.async { self?.publish(bands) }
        }
        guard status == noErr, let proc else {
            log.error("Could not create the audio callback")
            stop()
            return
        }
        procID = proc
        log.info("Audio tap running at \(format?.mSampleRate ?? 0) Hz, \(format?.mChannelsPerFrame ?? 0) channels")
        if AudioDeviceStart(aggregate, proc) != noErr {
            log.error("Could not start the audio tap")
            stop()
        }
    }

    private func stop() {
        if let procID, aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        procID = nil
        if aggregateID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateID) }
        aggregateID = kAudioObjectUnknown
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        tapID = kAudioObjectUnknown
        analyzer = nil
        isLive = false
        levels = [Float](repeating: 0, count: Self.bandCount)
    }

    private func publish(_ bands: [Float]) {
        guard users > 0 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if bands.contains(where: { $0 > 0.02 }) { lastSound = now }
        levels = bands
        let live = now - lastSound < 1.0
        if live != isLive { log.info("Music bars \(live ? "follow live audio" : "fall back to the loop", privacy: .public)") }
        isLive = live
        observers.values.forEach { $0() }
    }

    // MARK: - Helpers

    private static func defaultOutputUID() -> String? {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr
        else { return nil }
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        address.mSelector = kAudioDevicePropertyDeviceUID
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid) == noErr, let uid else { return nil }
        return uid.takeRetainedValue() as String
    }

    private static func tapFormat(_ tap: AudioObjectID) -> AudioStreamBasicDescription? {
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(tap, &address, 0, nil, &size, &format) == noErr else { return nil }
        return format
    }
}

/// Turns float audio blocks into six smoothed band levels (0…1). Runs on the audio queue.
nonisolated final class SpectrumAnalyzer: @unchecked Sendable {
    static let fftSize = 1024
    /// Band edges in Hz: bass to treble, one band per bar.
    static let edges: [Float] = [40, 150, 400, 1_000, 2_500, 6_000, 14_000]

    private let sampleRate: Float
    private let setup: FFTSetup
    private let log2n = vDSP_Length(10)
    private var window = [Float](repeating: 0, count: SpectrumAnalyzer.fftSize)
    private var buffer = [Float]()
    private var smoothed = [Float](repeating: 0, count: SystemAudioSpectrum.bandCount)
    private var peak: Float = 1e-4
    /// Music has far less energy up high; lift the upper bands so they still move.
    static let bandGain: [Float] = [1, 1.2, 1.6, 2.2, 3, 4]
    private var lastPublish: TimeInterval = 0

    init(sampleRate: Float) {
        self.sampleRate = sampleRate > 0 ? sampleRate : 48_000
        setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        vDSP_hann_window(&window, vDSP_Length(Self.fftSize), Int32(vDSP_HANN_NORM))
        buffer.reserveCapacity(Self.fftSize * 2)
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    /// Adds one IO block; returns new levels about 30 times a second.
    func process(_ input: UnsafePointer<AudioBufferList>) -> [Float]? {
        let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let first = list.first, let data = first.mData else { return nil }
        let channels = max(1, Int(first.mNumberChannels))
        let frames = Int(first.mDataByteSize) / (MemoryLayout<Float>.size * channels)
        let samples = data.assumingMemoryBound(to: Float.self)
        for frame in 0..<frames { buffer.append(samples[frame * channels]) }  // left channel is enough
        guard buffer.count >= Self.fftSize else { return nil }
        let block = Array(buffer.suffix(Self.fftSize))
        buffer.removeFirst(buffer.count - Self.fftSize / 2)

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPublish >= 1.0 / 30 else { return nil }
        lastPublish = now
        return bands(of: block)
    }

    func bands(of block: [Float]) -> [Float] {
        var windowed = [Float](repeating: 0, count: Self.fftSize)
        vDSP_vmul(block, 1, window, 1, &windowed, 1, vDSP_Length(Self.fftSize))
        let half = Self.fftSize / 2
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { src in
                    src.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }
        let binHz = sampleRate / Float(Self.fftSize)
        var energies = [Float](repeating: 0, count: SystemAudioSpectrum.bandCount)
        for band in 0..<SystemAudioSpectrum.bandCount {
            let low = max(1, Int(Self.edges[band] / binHz))
            let high = min(half - 1, max(low + 1, Int(Self.edges[band + 1] / binHz)))
            var energy: Float = 0
            magnitudes.withUnsafeBufferPointer { vDSP_meanv($0.baseAddress! + low, 1, &energy, vDSP_Length(high - low)) }
            energies[band] = energy * Self.bandGain[band]
        }
        // One shared, slowly decaying peak keeps the bars relative to each other.
        peak = max(energies.max() ?? 0, peak * 0.995, 1e-4)
        var result = [Float](repeating: 0, count: SystemAudioSpectrum.bandCount)
        for band in 0..<SystemAudioSpectrum.bandCount {
            let level = min(1, energies[band] / peak)
            // Fast rise, slower fall, like a VU meter.
            smoothed[band] = level > smoothed[band] ? level : smoothed[band] * 0.82 + level * 0.18
            result[band] = energies[band] < 1e-4 ? 0 : smoothed[band]
        }
        return result
    }
}
