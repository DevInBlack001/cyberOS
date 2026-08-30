import QtQuick
import QtQuick.Layouts
import Quickshell
import ".." as Cyber

PanelWindow {
    id: bar
    anchors { left: true; right: true; top: true }
    implicitHeight: Cyber.Theme.barHeight
    margins { left: 5; right: 5; top: 2 }
    exclusiveZone: implicitHeight + 4
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(Cyber.Theme.bg, Cyber.Theme.barAlpha)
        border.width: 1
        border.color: Cyber.Theme.border

        RowLayout {                       // left
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
            spacing: 6
            BarModule { icon: "\uf00a"; tooltip: "Applications"; onClicked: launcher.activeAsync = true }
            InstallButton {}
            Workspaces {}
            Media {}
        }
        WindowTitle { anchors.centerIn: parent }   // center
        RowLayout {                       // right
            id: right
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
            spacing: 6
            Tray {}
            BluetoothChip {}
            Audio {}
            Network {}
            SysStats {}
            Battery {}
            ClockChip {}
            BarModule { icon: "\uf011"; onClicked: powerMenu.activeAsync = true }
        }
    }
}
