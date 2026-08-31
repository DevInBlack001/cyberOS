import QtQuick
import "."
import ".." as Cyber

// Ported verbatim from the GTK wizard's page_mode() + on_mode_toggled() +
// refresh_mode_hint() + the "mode" branches of sync_buttons()/on_next()
// (cyberos-install-gui, page_mode ~181-217, on_mode_toggled/refresh_mode_hint
// ~219-238, sync_buttons/on_next gating ~444-463). Three exclusive rows,
// default "erase" (WizState.mode's own default), a hint label fed by the
// ported refresh_mode_hint strings, and the 25 GiB alongside gate.
//
// The GTK original computed free_space_gib() synchronously right inside
// sync_buttons(), so Next's enabled state and the hint text were always in
// lockstep with the true answer. Probe.freeSpaceGib() here is async
// (Process can never be synchronous), so `ready` is false whenever mode is
// "alongside" AND either no resolved answer exists yet OR the resolved
// answer is under 25 GiB -- a probe in flight is treated exactly like "not
// enough space" so Next can never flash enabled before the real number is
// known. The hint mirrors that: it shows nothing for alongside while a
// probe is pending, rather than a stale or guessed number.
Item {
    id: root

    readonly property var modes: [
        { key: "alongside", title: "Install alongside",
          subtitle: "Use existing free space. Other operating systems and their files are left alone." },
        { key: "erase", title: "Erase the whole disk",
          subtitle: "Everything currently on the disk is destroyed." },
        { key: "manual", title: "Custom partitioning",
          subtitle: "Choose which existing partitions to use." }
    ]

    // True while a freeSpaceGib() call for the *currently selected*
    // disk+mode has been issued but not yet resolved. Starts true so an
    // alongside default (not reachable today since WizState.mode defaults
    // to "erase", but a future back-navigation could re-enter this page
    // with mode already "alongside") never briefly reads as "ready" before
    // the first refresh has had a chance to run.
    property bool _freeSpacePending: true

    function refreshFreeSpace() {
        if (Cyber.WizState.mode !== "alongside" || !Cyber.WizState.disk) {
            root._freeSpacePending = false;
            return;
        }
        var disk = Cyber.WizState.disk;
        var mode = Cyber.WizState.mode;
        root._freeSpacePending = true;
        Cyber.Probe.freeSpaceGib(disk, function (gib) {
            // Stale-callback guard: ignore a result for a disk/mode that is
            // no longer selected (the user switched again before this
            // resolved).
            if (Cyber.WizState.disk !== disk || Cyber.WizState.mode !== mode) return;
            Cyber.WizState.freeGib = gib;
            root._freeSpacePending = false;
        });
    }

    Component.onCompleted: root.refreshFreeSpace()
    Connections {
        target: Cyber.WizState
        function onModeChanged() { root.refreshFreeSpace(); }
        function onDiskChanged() { root.refreshFreeSpace(); }
    }

    // Mirrors sync_buttons(): `enough = mode != "alongside" or
    // free_space_gib(...) >= 25`, with "no resolved answer yet" folded into
    // "not enough" so an in-flight probe can never leave Next enabled.
    property bool ready: Cyber.WizState.mode !== "alongside"
                         || (!root._freeSpacePending && Cyber.WizState.freeGib >= 25)
    property string nextLabel: "Next"

    // Ported verbatim from refresh_mode_hint(). The GTK original's early
    // "if not self.disks: return" left whatever hint text was already on
    // screen in place; there is no prior text to preserve on first render
    // here, so the empty-disks case just returns "".
    function _hintText() {
        if (Cyber.Probe.disks.length === 0) return "";
        var disk = Cyber.WizState.disk;
        if (Cyber.WizState.mode === "alongside") {
            if (root._freeSpacePending) return "";
            var gib = Cyber.WizState.freeGib;
            if (gib < 25) {
                return "Only " + gib + " GiB of unallocated space on " + disk + ". At least "
                     + "25 GiB is needed. Shrink an existing partition first — "
                     + "Disk Management on Windows, gparted on Linux — then come back.";
            }
            return gib + " GiB of free space on " + disk + " will be used. Existing "
                 + "partitions are not resized or deleted.";
        } else if (Cyber.WizState.mode === "erase") {
            return "Every partition on " + disk + " will be destroyed.";
        }
        return "";
    }

    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Installation type"
            color: Cyber.Theme.fg
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 8; bold: true }
        }

        Text {
            width: parent.width
            text: "What should the installer do?"
            color: Cyber.Theme.muted
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
        }

        Repeater {
            model: root.modes

            delegate: Item {
                width: parent ? parent.width : 0
                height: rowField.implicitHeight

                Field {
                    id: rowField
                    anchors.fill: parent
                    label: modelData.title
                    subtitle: modelData.subtitle

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: "transparent"
                        border.width: 2
                        border.color: Cyber.WizState.mode === modelData.key ? Cyber.Theme.accent : Cyber.Theme.border

                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: Cyber.Theme.accent
                            visible: Cyber.WizState.mode === modelData.key
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Cyber.WizState.mode = modelData.key
                }
            }
        }

        Hint {
            width: parent.width
            text: root._hintText()
        }
    }
}
