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
    implicitWidth: 360
    implicitHeight: 560
    color: "transparent"
    focusable: true
    aboveWindows: true

    readonly property int rowHeight: 26

    // Category chips. First match in priority order wins; anything unmatched
    // lands in Utilities. freedesktop "Security" is a registered additional
    // category -- our own .desktop entries (metasploit.desktop) set it, and
    // nameOverrides catches shipped tools whose upstream Categories don't
    // (wireshark says Network;Monitor).
    readonly property var groups: ["All", "Security", "Development", "Internet",
        "Office", "Graphics", "Media", "System", "Utilities"]
    property string activeGroup: "All"

    // Tab/Backtab and Left/Right both drive this -- keyboard-only category
    // switching, no scrolling required to reach a chip off the edge of the
    // panel's width. catList (below) keeps the active chip in view itself.
    function cycleGroup(delta) {
        const i = root.groups.indexOf(root.activeGroup);
        root.activeGroup = root.groups[(i + delta + root.groups.length) % root.groups.length];
    }

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
    onFilteredChanged: list.currentIndex = filtered.length > 0 ? 0 : -1

    // No highlighted entry (empty filter results) is a no-op, not a close --
    // matches rofi: Return with nothing matched does nothing, it doesn't
    // dismiss the launcher.
    function launch(entry) {
        if (!entry) return;
        entry.execute();
        root.closeRequested();
    }

    // Sharp corners, a single hairline border, no chip/pill decoration below
    // -- a plain terminal box rather than the rest of the shell's rounded
    // Theme.radius look, deliberately: this is the one surface styled after
    // a minimal TUI launcher (dmenu/fzf), not the desktop chrome around it.
    // Border is Theme.accent (green), not the neutral Theme.border every
    // other panel uses: it ties the box outline to the same colour as the
    // prompt glyph and the selection/active-category markers inside it,
    // over Theme.accent2 (gold) which would compete with the launch icons'
    // own colours instead of framing them.
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Cyber.Theme.bg
        border.width: 1
        border.color: Cyber.Theme.accent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: ">"
                    color: Cyber.Theme.accent
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 2; bold: true }
                }

                TextField {
                    id: filterField
                    Layout.fillWidth: true
                    placeholderText: "search applications..."
                    placeholderTextColor: Cyber.Theme.muted
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 2 }
                    selectByMouse: true
                    background: Rectangle { color: "transparent" }

                    // List navigation and category switching both live on the
                    // filter field, not on the ListViews themselves: the
                    // field holds focus for the whole time the launcher is
                    // open (typing always works) and forwards the keys they
                    // care about. Left/Right switch categories -- the same
                    // action as Tab/Backtab -- rather than moving the text
                    // cursor: a keyboard-only launcher has no scrollbar or
                    // wheel to reach for, so both the arrow keys and Tab
                    // reach every category without one.
                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Down:
                            list.incrementCurrentIndex();
                            event.accepted = true;
                            break;
                        case Qt.Key_Up:
                            list.decrementCurrentIndex();
                            event.accepted = true;
                            break;
                        case Qt.Key_Right:
                        case Qt.Key_Tab:
                            root.cycleGroup(1);
                            event.accepted = true;
                            break;
                        case Qt.Key_Left:
                        case Qt.Key_Backtab:
                            root.cycleGroup(-1);
                            event.accepted = true;
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            root.launch(root.filtered[list.currentIndex]);
                            event.accepted = true;
                            break;
                        case Qt.Key_Escape:
                            root.closeRequested();
                            event.accepted = true;
                            break;
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Cyber.Theme.accent }

            // Horizontal ListView, not a RowLayout: nine chips plus brackets
            // on the active one don't fit the panel's narrow width, and a
            // RowLayout has no way to bring an off-screen chip into view.
            // No wheel/drag handling here on purpose -- Left/Right and
            // Tab/Backtab (filterField's Keys.onPressed) are the only way to
            // change category, and positionViewAtIndex below keeps whichever
            // one is active on-screen, clipped or not.
            ListView {
                id: catList
                Layout.fillWidth: true
                Layout.preferredHeight: Cyber.Theme.fontSize + 8
                orientation: ListView.Horizontal
                clip: true
                spacing: 14
                interactive: false

                Connections {
                    target: root
                    function onActiveGroupChanged() {
                        catList.positionViewAtIndex(root.groups.indexOf(root.activeGroup), ListView.Contain);
                    }
                }

                model: root.groups
                delegate: Text {
                    id: chip
                    required property string modelData
                    text: root.activeGroup === chip.modelData ? "[" + chip.modelData + "]" : chip.modelData
                    color: root.activeGroup === chip.modelData ? Cyber.Theme.accent : Cyber.Theme.muted
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 3 }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.activeGroup = chip.modelData
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                currentIndex: 0

                // A plain JS array bound straight to `model:` is treated as
                // a brand-new model on every reassignment -- QQmlDelegateModel
                // has no way to tell "same list, some entries added/removed"
                // from "unrelated new list", so it destroys and recreates
                // every delegate on every keystroke. Measured before this
                // fix (back when this was a GridView with icon delegates):
                // opening the launcher and typing two characters ("f" then
                // "fi") produced ~1250 delegate creations/destructions
                // total, including repeat churn for apps present in *both*
                // filter results -- a real flicker/lag risk under the spec's
                // safe-graphics (software rendering) constraint.
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
                // delegate is kept alive, not rebuilt.
                model: ScriptModel {
                    values: root.filtered
                    comparisonMode: ObjectComparison.Identity
                }

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: list.width
                    height: root.rowHeight

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        spacing: 8

                        Text {
                            text: cell.index === list.currentIndex ? ">" : " "
                            color: Cyber.Theme.accent
                            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                        }
                        IconImage {
                            implicitSize: 16
                            // Same fallback as the old grid delegate: an entry
                            // whose `icon` doesn't resolve in the icon theme
                            // gets a generic placeholder instead of a blank
                            // gap in the row.
                            source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                        }
                        Text {
                            Layout.fillWidth: true
                            text: cell.modelData.name
                            textFormat: Text.PlainText
                            color: cell.index === list.currentIndex ? Cyber.Theme.fg : Cyber.Theme.muted
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = cell.index
                        onClicked: root.launch(cell.modelData)
                    }
                }
            }
        }
    }

    Component.onCompleted: filterField.forceActiveFocus()
}
