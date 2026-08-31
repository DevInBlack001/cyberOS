import QtQuick
import QtQuick.Layouts
import ".." as Cyber

// Ported verbatim from the GTK wizard's page_confirm() (~373-381) and
// fill_summary() (~484-499) (cyberos-install-gui). fill_summary() built one
// Pango-markup label with a row per answer ("<b>Label</b>\tvalue"); here
// each row is its own SummaryRow-shaped Text pair inside a Column, same six
// rows in the same order, same wording. The GTK original called
// fill_summary() once, from on_next()'s "options" branch, right before
// advancing onto this page -- values here are instead read live off
// WizState/Probe so back-then-forward navigation always shows the current
// answers without a separate refresh hook.
//
// "I understand and want to continue" is a real checkbox (not
// QtQuick.Controls' CheckBox, to keep the same hand-themed look every other
// control in this wizard already uses -- see the encrypt/format-EFI toggles
// in OptionsPage.qml/CustomPage.qml) gating `ready`, mirroring
// self.agree.connect("toggled", ...) -> sync_buttons(). nextLabel is
// "Install", same as sync_buttons()'s `self.next.set_label("Install")` for
// this page.
Item {
    id: root

    property bool agreed: false
    property bool ready: root.agreed
    property string nextLabel: "Install"

    // Ported from selected_disk()/fill_summary()'s `self.disks[...]` lookup:
    // the (name, size, model) tuple for the chosen disk, off Probe.disks
    // (same shape DiskPage.qml already reads from).
    function _diskInfo() {
        var disks = Cyber.Probe.disks;
        for (var i = 0; i < disks.length; i++) {
            if (disks[i].name === Cyber.WizState.disk) return disks[i];
        }
        return { name: Cyber.WizState.disk, size: "", model: "" };
    }

    // Ported verbatim from fill_summary()'s `what` dict.
    function _actionText() {
        var mode = Cyber.WizState.mode;
        if (mode === "alongside") return "install alongside, using free space only";
        if (mode === "manual") return "use the partitions chosen";
        return "ERASE the whole disk";
    }

    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Ready to install"
            color: Cyber.Theme.fg
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 8; bold: true }
        }

        Column {
            width: parent.width
            spacing: 8

            RowLayout {
                width: parent.width
                spacing: 10
                Text {
                    Layout.preferredWidth: 90
                    text: "Action"
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: root._actionText()
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 10
                Text {
                    Layout.preferredWidth: 90
                    text: "Disk"
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: root._diskInfo().name + "  " + root._diskInfo().size
                          + (root._diskInfo().model ? "  " + root._diskInfo().model : "")
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 10
                Text {
                    Layout.preferredWidth: 90
                    text: "User"
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: Cyber.WizState.user.trim()
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 10
                Text {
                    Layout.preferredWidth: 90
                    text: "Name"
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: Cyber.WizState.host.trim()
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 10
                Text {
                    Layout.preferredWidth: 90
                    text: "Zone"
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: Cyber.WizState.tz
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 10
                Text {
                    Layout.preferredWidth: 90
                    text: "Disk format"
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: Cyber.WizState.fs + ", " + Cyber.WizState.swapGib + " GiB swap"
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
            }
        }

        // A plain Item wraps the Row instead of putting the click target
        // inside it: Row is a Positioner, and Positioners assert/warn on
        // any child anchor that affects their own layout axis (left,
        // right, horizontalCenter, fill, centerIn -- see
        // QTBUG/qml Row docs) -- exactly the anchors a full-row click
        // target needs. Keeping the MouseArea a sibling of the Row, sized
        // off the Row's own implicit size, avoids the warning and still
        // covers the same area a fourth Row child would have.
        Item {
            width: agreeRow.width
            height: agreeRow.height

            Row {
                id: agreeRow
                spacing: 10
                // Keyboard-operable checkbox: Tab reaches this row, Space
                // or Return/Enter toggles it -- mirroring the GTK
                // original's real checkbox widget, which was natively
                // both mouse- and keyboard-operable.
                activeFocusOnTab: true
                Keys.onSpacePressed: root.agreed = !root.agreed
                Keys.onReturnPressed: root.agreed = !root.agreed
                Keys.onEnterPressed: root.agreed = !root.agreed

                Rectangle {
                    id: agreeBox
                    width: 22
                    height: 22
                    radius: Cyber.Theme.radius / 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: Cyber.Theme.surface
                    border.width: agreeRow.activeFocus ? 2 : 1
                    border.color: (root.agreed || agreeRow.activeFocus) ? Cyber.Theme.accent : Cyber.Theme.border

                    Text {
                        anchors.centerIn: parent
                        visible: root.agreed
                        text: "\uf00c"
                        color: Cyber.Theme.accent
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "I understand and want to continue"
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.agreed = !root.agreed
            }
        }
    }
}
