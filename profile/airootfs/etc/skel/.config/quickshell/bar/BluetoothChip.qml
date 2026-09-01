import QtQuick
import Quickshell
import Quickshell.Bluetooth
import ".." as Cyber

BarModule {
    id: bt
    property var adapter: Bluetooth.defaultAdapter
    property bool anyConnected: adapter?.devices.values.some(d => d.connected) ?? false

    icon: (adapter?.enabled ?? false) ? "\uf293" : "\udb80\udcb2"
    iconColor: anyConnected ? Cyber.Theme.accent : Cyber.Theme.fg
    tooltip: adapter?.enabled ? (anyConnected ? "Connected" : "On") : "Off"

    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "bt", "toggle"])
}
