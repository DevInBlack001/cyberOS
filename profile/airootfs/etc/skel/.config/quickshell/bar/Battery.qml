import QtQuick
import Quickshell.Services.UPower
import ".." as Cyber

BarModule {
    id: battery
    property var device: UPower.displayDevice
    visible: device?.isLaptopBattery ?? false

    // battery_10..battery_90, then battery (100%, full) -- brief's array,
    // verified against the shipped Nerd Font cmap.
    readonly property var levelIcons: [
        "\udb80\udc7a", "\udb80\udc7b", "\udb80\udc7c", "\udb80\udc7d", "\udb80\udc7e",
        "\udb80\udc7f", "\udb80\udc80", "\udb80\udc81", "\udb80\udc82", "\udb80\udc79"
    ]
    // battery_charging_20/30/40/60/80/90/100 -- the real font has no 10/50/70
    // charging glyphs, so those deciles fall back to the nearest neighbour
    // (rounding a tie up). See task-3-report.md.
    readonly property var chargingIcons: [
        "\udb80\udc86", "\udb80\udc86", "\udb80\udc87", "\udb80\udc88", "\udb80\udc89",
        "\udb80\udc89", "\udb80\udc8a", "\udb80\udc8a", "\udb80\udc8b", "\udb80\udc85"
    ]

    property real pct: device?.percentage ?? 0
    property bool charging: device?.state === UPowerDeviceState.Charging
    property int levelIdx: Math.max(0, Math.min(9, Math.floor(pct * 10)))

    icon: charging ? chargingIcons[levelIdx] : levelIcons[levelIdx]
    iconColor: pct < 0.10 ? Cyber.Theme.alert : pct < 0.20 ? Cyber.Theme.accent2 : Cyber.Theme.fg
    label: Math.round(pct * 100) + "%"
    tooltip: charging ? "Charging" : "On battery"

    onClicked: powerMenu.activeAsync = true
}
