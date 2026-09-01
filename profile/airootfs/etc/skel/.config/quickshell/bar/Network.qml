import QtQuick
import Quickshell
import Quickshell.Networking
import ".." as Cyber

BarModule {
    id: net
    // md-ethernet (wired) -- the brief's codepoint for this slot is actually
    // "wifi_strength_4" in the shipped Nerd Font; verified against the real
    // cmap and swapped for the correct ethernet glyph. See task-3-report.md.
    readonly property string ethernetIcon: "\udb80\ude00"
    // wifi_strength_1..4, indexed by signal bucket
    readonly property var wifiIcons: ["\udb82\udd1f", "\udb82\udd22", "\udb82\udd25", "\udb82\udd28"]
    // wifi_strength_off -- the brief's codepoint here is actually
    // "wifi_strength_4_lock" (a secured-network glyph); swapped for the real
    // disconnected icon. See task-3-report.md.
    readonly property string disconnectedIcon: "\udb82\udd2d"

    property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.hasLink) ?? null
    property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    property var activeWifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null

    icon: wiredDevice ? ethernetIcon
        : activeWifiNetwork ? wifiIcons[Math.min(3, Math.floor(activeWifiNetwork.signalStrength / 25))]
        : disconnectedIcon
    iconColor: (wiredDevice || activeWifiNetwork) ? Cyber.Theme.fg : Cyber.Theme.muted
    tooltip: wiredDevice ? "Wired connection"
        : activeWifiNetwork ? activeWifiNetwork.name + " (" + Math.round(activeWifiNetwork.signalStrength) + "%)"
        : "Disconnected"

    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "wifi", "toggle"])
}
