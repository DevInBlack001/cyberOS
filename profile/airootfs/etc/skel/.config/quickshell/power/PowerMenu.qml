import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import ".." as Cyber

// Replaces the deleted rofi/powermenu.sh. Opened/closed via
// `qs ipc call power toggle` (shell.qml's IpcHandler flips the owning
// LazyLoader's `active`), so this component is created fresh on every open
// and destroyed on every close -- there is no persistent "shown" state to
// manage here. Closing from the inside (Escape, or after running an action)
// is done through the `closeRequested` signal: shell.qml wires that signal
// to `powerMenu.active = false` where the `powerMenu` id is in scope (this
// file's own id namespace does not see the LazyLoader's id).
PanelWindow {
    id: root

    signal closeRequested()

    anchors { left: false; right: false; top: false; bottom: false }
    implicitWidth: 260
    implicitHeight: 220
    color: "transparent"
    focusable: true
    aboveWindows: true

    readonly property var actions: [
        { icon: "\uf023", label: "Lock",      run: () => Quickshell.execDetached(["hyprlock"]) },
        { icon: "\uf2f5", label: "Log out",   run: () => Hyprland.dispatch("hl.dsp.exit()") },
        { icon: "\uf2f9", label: "Reboot",    run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { icon: "\uf011", label: "Shut down", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
    ]
    property int selected: 0

    function activate(idx) {
        root.actions[idx].run();
        root.closeRequested();
    }

    Rectangle {
        anchors.fill: parent
        radius: Cyber.Theme.radius
        color: Cyber.Theme.bg
        border.width: 1
        border.color: Cyber.Theme.border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Cyber.Theme.radius / 2
                    color: index === root.selected ? Cyber.Theme.sel : "transparent"
                    border.width: index === root.selected ? 1 : 0
                    border.color: Cyber.Theme.accent

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        spacing: 10

                        Text {
                            text: modelData.icon
                            color: Cyber.Theme.fg
                            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 2 }
                        }
                        Text {
                            text: modelData.label
                            color: Cyber.Theme.fg
                            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selected = index
                        onClicked: root.activate(index)
                    }
                }
            }
        }
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down) {
                root.selected = (root.selected + 1) % root.actions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                root.selected = (root.selected - 1 + root.actions.length) % root.actions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activate(root.selected);
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.closeRequested();
                event.accepted = true;
            }
        }
    }

    Component.onCompleted: keyHandler.forceActiveFocus()
}
