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
    implicitHeight: 460
    color: "transparent"
    focusable: true
    aboveWindows: true

    readonly property int columns: 5

    // Category chips. First match in priority order wins; anything unmatched
    // lands in Utilities. freedesktop "Security" is a registered additional
    // category -- our own .desktop entries (metasploit.desktop) set it, and
    // nameOverrides catches shipped tools whose upstream Categories don't
    // (wireshark says Network;Monitor).
    readonly property var groups: ["All", "Security", "Development", "Internet",
        "Office", "Graphics", "Media", "System", "Utilities"]
    property string activeGroup: "All"

    readonly property var nameOverrides: ({
        "Wireshark": "Security",
        "Ghidra": "Security"
    })

    function groupOf(entry) {
        const o = nameOverrides[entry.name];
        if (o !== undefined) return o;
        const c = entry.categories;
        const has = list => list.some(x => c.includes(x));
        if (has(["Security"])) return "Security";
        if (has(["Development", "IDE", "Debugger", "RevisionControl"])) return "Development";
        if (has(["Network", "WebBrowser", "Email", "P2P"])) return "Internet";
        if (has(["Office", "WordProcessor", "Spreadsheet", "Presentation"])) return "Office";
        if (has(["Graphics", "Photography"])) return "Graphics";
        if (has(["AudioVideo", "Audio", "Video", "Player"])) return "Media";
        if (has(["System", "Settings", "HardwareSettings", "Monitor",
                 "TerminalEmulator", "FileManager", "Emulator"])) return "System";
        return "Utilities";
    }

    // Filtered + sorted app list. Recomputes whenever the filter text or
    // active category changes (the reads of `filterField.text` and
    // `root.activeGroup` below each establish a binding dependency);
    // noDisplay entries are dropped, case-insensitive substring match on
    // name, alphabetical order.
    readonly property var filtered: {
        const q = filterField.text.trim().toLowerCase();
        return DesktopEntries.applications.values
            .filter(a => !a.noDisplay
                && (root.activeGroup === "All" || root.groupOf(a) === root.activeGroup)
                && (q === "" || a.name.toLowerCase().includes(q)))
            .sort((a, b) => a.name.localeCompare(b.name));
    }
    // Re-select the first result whenever the filtered set changes (every
    // keystroke) -- matches rofi (typing always re-highlights the top hit).
    onFilteredChanged: grid.currentIndex = filtered.length > 0 ? 0 : -1

    // No highlighted entry (empty filter results) is a no-op, not a close --
    // matches rofi: Return with nothing matched does nothing, it doesn't
    // dismiss the launcher.
    function launch(entry) {
        if (!entry) return;
        entry.execute();
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
                    case Qt.Key_Tab: {
                        const i = root.groups.indexOf(root.activeGroup);
                        root.activeGroup = root.groups[(i + 1) % root.groups.length];
                        event.accepted = true;
                        break;
                    }
                    case Qt.Key_Backtab: {
                        const i = root.groups.indexOf(root.activeGroup);
                        root.activeGroup = root.groups[(i - 1 + root.groups.length) % root.groups.length];
                        event.accepted = true;
                        break;
                    }
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

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: root.groups
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        implicitWidth: chipLabel.implicitWidth + 14
                        implicitHeight: chipLabel.implicitHeight + 8
                        radius: height / 2
                        color: root.activeGroup === chip.modelData ? Cyber.Theme.sel : "transparent"
                        border.width: 1
                        border.color: root.activeGroup === chip.modelData ? Cyber.Theme.accent : Cyber.Theme.border

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: chip.modelData
                            color: root.activeGroup === chip.modelData ? Cyber.Theme.fg : Cyber.Theme.muted
                            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 3 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.activeGroup = chip.modelData
                        }
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
                currentIndex: 0

                // A plain JS array bound straight to `model:` is treated as
                // a brand-new model on every reassignment -- QQmlDelegateModel
                // has no way to tell "same list, some entries added/removed"
                // from "unrelated new list", so it destroys and recreates
                // every delegate (all IconImages included) on every
                // keystroke. Measured before this fix: opening the launcher
                // and typing two characters ("f" then "fi") produced ~1250
                // delegate creations/destructions total, including repeat
                // churn for apps present in *both* filter results -- a real
                // flicker/lag risk under the spec's safe-graphics (software
                // rendering) constraint.
                //
                // ScriptModel (Quickshell core) exists precisely for this:
                // it wraps a JS array as a real QAbstractListModel and diffs
                // old vs new `values` to emit minimal insert/remove/move
                // signals instead of a full reset. `comparisonMode:
                // ObjectComparison.Identity` (set explicitly here, matching
                // the default) diffs by object identity, which is correct
                // for DesktopEntry: entries are stable QObjects owned by the
                // DesktopEntries singleton, never recreated between
                // keystrokes -- so an app present in both the old and new
                // filtered set is recognised as the *same* row and its
                // delegate (and its IconImage) is kept alive, not rebuilt.
                // Verified at runtime with temporary onCompleted/
                // onDestruction counters on the delegate: the same two
                // keystrokes after this fix produced zero destroy/recreate
                // churn for entries unaffected by the filter change (see
                // task-6-report.md's fix-report addendum for the exact
                // before/after counts).
                model: ScriptModel {
                    values: root.filtered
                    comparisonMode: ObjectComparison.Identity
                }

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
                                // Two-arg fallback overload: an entry whose
                                // `icon` doesn't resolve in the icon theme
                                // (host-app-index dependent, e.g. some
                                // packages ship a broken Icon= key) gets a
                                // generic placeholder instead of Image
                                // logging a "could not load icon" warning.
                                source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
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
