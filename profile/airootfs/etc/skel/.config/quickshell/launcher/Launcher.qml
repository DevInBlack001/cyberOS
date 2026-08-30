import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".." as Cyber

// Replaces the deleted `rofi -show drun`. Opened/closed via
// `qs ipc call launcher toggle` (shell.qml's IpcHandler flips the owning
// LazyLoader's `active`), so -- same shape as PowerMenu.qml -- this
// component is created fresh on every open and destroyed on every close.
// That gives the filter text its "resets on every open" behaviour for
// free: `filterField.text` starts empty on every fresh instantiation, no
// manual reset needed. Closing from the inside (Escape, or after launching
// an app) goes through the `closeRequested` signal, wired in shell.qml
// where the `launcher` LazyLoader id is in scope (this file's own id
// namespace can't see it).
PanelWindow {
    id: root

    signal closeRequested()

    anchors { left: false; right: false; top: false; bottom: false }
    implicitWidth: 560
    implicitHeight: 420
    color: "transparent"
    focusable: true
    aboveWindows: true

    readonly property int columns: 5

    // Filtered + sorted app list. Recomputes whenever the filter text
    // changes (the read of `filterField.text` below establishes that
    // binding dependency); noDisplay entries are dropped, case-insensitive
    // substring match on name, alphabetical order.
    readonly property var filtered: {
        const q = filterField.text.trim().toLowerCase();
        return DesktopEntries.applications.values
            .filter(a => !a.noDisplay && (q === "" || a.name.toLowerCase().includes(q)))
            .sort((a, b) => a.name.localeCompare(b.name));
    }

    function launch(entry) {
        if (entry) entry.execute();
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
            spacing: 8

            TextField {
                id: filterField
                Layout.fillWidth: true
                placeholderText: "Search applications..."
                placeholderTextColor: Cyber.Theme.muted
                color: Cyber.Theme.fg
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 2 }
                selectByMouse: true
                background: Rectangle { color: "transparent" }

                // Grid navigation lives on the filter field, not the
                // GridView: the field holds focus for the whole time the
                // launcher is open (typing always works) and forwards the
                // keys the grid cares about to GridView's own
                // moveCurrentIndex*() methods -- grid-aware (wraps at
                // row/column boundaries per GridView's own semantics)
                // without hand-rolled index-plus-or-minus-columns math.
                // Unhandled keys fall through to normal text editing since
                // event.accepted is only set for the cases below.
                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Down:
                        grid.moveCurrentIndexDown();
                        event.accepted = true;
                        break;
                    case Qt.Key_Up:
                        grid.moveCurrentIndexUp();
                        event.accepted = true;
                        break;
                    case Qt.Key_Left:
                        grid.moveCurrentIndexLeft();
                        event.accepted = true;
                        break;
                    case Qt.Key_Right:
                        grid.moveCurrentIndexRight();
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.launch(root.filtered[grid.currentIndex]);
                        event.accepted = true;
                        break;
                    case Qt.Key_Escape:
                        root.closeRequested();
                        event.accepted = true;
                        break;
                    }
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: width / root.columns
                cellHeight: 96
                model: root.filtered
                currentIndex: 0
                onModelChanged: currentIndex = 0

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: Cyber.Theme.radius / 2
                        color: cell.index === grid.currentIndex ? Cyber.Theme.sel : "transparent"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            IconImage {
                                Layout.alignment: Qt.AlignHCenter
                                implicitSize: 40
                                source: Quickshell.iconPath(cell.modelData.icon)
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                text: cell.modelData.name
                                color: Cyber.Theme.fg
                                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 2 }
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: grid.currentIndex = cell.index
                            onClicked: root.launch(cell.modelData)
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: filterField.forceActiveFocus()
}
