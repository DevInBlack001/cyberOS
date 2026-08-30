import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import ".." as Cyber

RowLayout {
    spacing: 2
    // waybar parity: workspaces 1-5 always shown (persistent), higher ones only when they exist
    Repeater {
        model: 10
        Rectangle {
            required property int index
            property int wsId: index + 1
            property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
            visible: wsId <= 5 || ws !== null
            implicitWidth: 22; implicitHeight: 22; radius: 11
            color: ws?.focused ? Cyber.Theme.accent
                 : ws?.urgent ? Cyber.Theme.alert
                 : ma.containsMouse ? Cyber.Theme.sel : "transparent"
            Text {
                anchors.centerIn: parent
                text: wsId
                color: ws?.focused ? Cyber.Theme.bg
                     : ws ? Cyber.Theme.fg : Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
            }
            MouseArea {
                id: ma; anchors.fill: parent; hoverEnabled: true
                onClicked: ws ? ws.activate()
                              : Hyprland.dispatch(`hl.dsp.focus({workspace=${wsId}})`)
            }
        }
    }
}
