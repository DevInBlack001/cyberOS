import QtQuick
import Quickshell
import ".." as Cyber

// Ported verbatim from the GTK wizard's page_done(): same title, same
// description, same "Restart now" action (sudo -n systemctl reboot, run
// detached exactly like the GTK button's subprocess.Popen). shell.qml hides
// both Back and Next on this page (same as GTK's sync_buttons), so ready/
// nextLabel below are never surfaced -- kept only for the convention every
// page in this wizard follows.
Item {
    id: root

    property bool ready: true
    property string nextLabel: "Next"

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 560)
        spacing: 24

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Installation complete"
            color: Cyber.Theme.fg
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 10; bold: true }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Remove the USB stick after the machine has shut down, then start it again."
            color: Cyber.Theme.muted
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
        }

        Rectangle {
            id: reboot
            anchors.horizontalCenter: parent.horizontalCenter
            width: rebootLabel.implicitWidth + 40
            height: 40
            radius: height / 2
            color: rebootArea.containsMouse ? Cyber.Theme.accent2 : Cyber.Theme.accent

            Text {
                id: rebootLabel
                anchors.centerIn: parent
                text: "Restart now"
                color: Cyber.Theme.bg
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize; bold: true }
            }
            MouseArea {
                id: rebootArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Quickshell.execDetached(["sudo", "-n", "systemctl", "reboot"])
            }
        }
    }
}
