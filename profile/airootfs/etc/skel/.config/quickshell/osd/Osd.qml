import QtQuick
import QtQuick.Layouts
import Quickshell
import ".." as Cyber

// Bottom-centre volume/brightness indicator, replacing swayosd-client's
// popup. shell.qml's `IpcHandler { target: "osd" }` writes the level/icon to
// show into the OsdState singleton and flips this LazyLoader's `active` --
// see OsdState.qml for why a singleton, not an id or loader-item write, is
// used to get the data in here. This window never needs to talk back to
// shell.qml (no signal like PowerMenu's `closeRequested`): it just hides
// itself on its own Timer.
PanelWindow {
    id: root

    anchors { left: false; right: false; top: false; bottom: true }
    margins.bottom: 40
    implicitWidth: 260
    implicitHeight: 48
    color: "transparent"
    aboveWindows: true

    // This is a transient overlay, not a dock: it must never reserve screen
    // space or shift the bar/other windows while it's briefly visible.
    // `exclusiveZone: 0` looks like the obvious way to say that, but this
    // Quickshell build's own qmltypes (quickshell-window.qmltypes) exposes a
    // separate `exclusionMode` enum -- Normal/Ignore/Auto -- alongside it;
    // `Ignore` is the one documented to never reserve space regardless of
    // `exclusiveZone`'s value, so both are set. Verified at runtime: `hyprctl
    // layers` shows the osd surface while visible with no change to the
    // bar's or any window's geometry (see task report).
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
        anchors.fill: parent
        radius: Cyber.Theme.radius
        color: Cyber.Theme.surface
        border.width: 1
        border.color: Cyber.Theme.border

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Text {
                text: Cyber.OsdState.icon
                color: Cyber.Theme.fg
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 2 }
            }

            Rectangle {
                id: track
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                Layout.alignment: Qt.AlignVCenter
                radius: 4
                color: Cyber.Theme.bg
                border.width: 1
                border.color: Cyber.Theme.border

                Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0, Math.min(1, Cyber.OsdState.level))
                    radius: 4
                    color: Cyber.Theme.accent
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.visible = false
    }

    // OsdState.seq is the "please (re)show" trigger -- see OsdState.qml. On
    // the very first show (this PanelWindow just got created by
    // `activeAsync = true`) `visible` already defaults to true and
    // Component.onCompleted starts the timer below; on every later ipc call
    // the item already exists, so it's this handler's job to re-show it and
    // restart the countdown.
    Connections {
        target: Cyber.OsdState
        function onSeqChanged() {
            root.visible = true;
            hideTimer.restart();
        }
    }

    Component.onCompleted: hideTimer.start()
}
