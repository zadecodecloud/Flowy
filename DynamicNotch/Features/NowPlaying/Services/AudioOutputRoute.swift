import CoreAudio
import Foundation

struct AudioOutputRoute: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let transportType: UInt32
    let isCurrent: Bool
    var modelUID: String? = nil

    var systemImageName: String {
        // Device identity wins over transport: AirPods Max also supports USB audio.
        let identity = (name + " " + (modelUID ?? "")).lowercased()
            .filter { $0.isLetter || $0.isNumber }
        if identity.contains("airpodsmax") { return "airpodsmax" }
        if identity.contains("airpodspro") { return "airpods.pro" }
        if identity.contains("airpods4") { return "airpods.gen4" }
        if identity.contains("airpods3") { return "airpods.gen3" }
        if identity.contains("airpods") { return "airpods" }
        if identity.contains("homepodmini") { return "homepodmini" }
        if identity.contains("homepod") { return "homepod" }
        if identity.contains("headphone") || identity.contains("headset") { return "headphones" }

        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            if identity.contains("macbook") { return "macbook" }
            if ["imac", "macmini", "macstudio", "macpro"].contains(where: identity.contains) {
                return "desktopcomputer"
            }
            return "speaker.wave.2.fill"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return identity.contains("speaker") ? "hifispeaker.fill" : "headphones"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return "tv"
        case kAudioDeviceTransportTypeUSB, kAudioDeviceTransportTypeThunderbolt:
            return "hifispeaker.fill"
        default:
            return "speaker.wave.2.fill"
        }
    }
}
