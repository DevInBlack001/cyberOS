import QtQuick
import QtQuick.Controls
import "."
import ".." as Cyber

// Ported verbatim from the GTK wizard's page_custom() + validate_custom() +
// refresh_partitions() (cyberos-install-gui, ~240-291). shell.qml only ever
// loads this page in manual mode -- WizState.skipped("custom") keeps
// next()/back() from stopping here otherwise (see WizState.qml) -- but the
// picker still needs a fresh Probe.partitions() call every time it IS
// entered, since the disk or its layout may have changed since the last
// visit.
Item {
    id: root

    property bool ready: root._problem().length === 0
    property string nextLabel: "Next"

    // Ported from Wizard.part_devices: the /dev path for each row of
    // Probe.partitions' result, indexed identically to rootCombo/efiCombo
    // below (refresh() below rebuilds both the combos and this array in
    // lockstep, same as refresh_partitions() did for part_devices and the
    // two string-list models).
    property var _parts: []

    // Ported from validate_custom(). Both pickers are single-choice
    // ComboBoxes, so every change is a deliberate, complete selection --
    // unlike AccountPage's/OptionsPage's free-text fields, there is no
    // "still mid-keystroke" state to protect against, so this hint (unlike
    // theirs) is shown live with no "has the user attempted Next yet" gate.
    // See AccountPage.qml/OptionsPage.qml for the keystroke-gated version of
    // this same port-pragmatically call, and shell.qml's Next button, which
    // this `ready` continuously drives (disabled rather than the GTK's
    // click-then-validate, since Next is a real button here, not a
    // Next-then-check step).
    function _problem() {
        if (root._parts.length === 0)
            return "No partitions on this disk. Create some first.";
        if (rootCombo.currentIndex === efiCombo.currentIndex)
            return "Root and the EFI partition must be different partitions.";
        return "";
    }

    // Ported from refresh_partitions(): ESP preselected by the first row
    // whose PARTTYPENAME contains "EFI"; root defaults to the first row that
    // is NOT the ESP (index 0 if there is no ESP at all -- which also means
    // efi defaults to 0, so root and efi collide on first render exactly as
    // they did in the GTK original, surfacing the "must be different
    // partitions" hint immediately rather than silently offering a bad
    // default).
    function refresh() {
        Cyber.Probe.partitions(Cyber.WizState.disk, function (rows) {
            // Guard against a destroyed root: WizState.next()/back() walk
            // the pages array in a single synchronous loop (see
            // WizState.qml), so a non-manual mode's Next click passes
            // through "custom" transiently -- the Loader (shell.qml)
            // creates this Item, Component.onCompleted fires refresh()
            // and spawns the async lsblk probe below, then the very next
            // loop iteration already lands on "account" and destroys this
            // Item, all before lsblk exits. Without this guard the
            // callback's first line throws ("Value is null") reaching
            // into an already-destroyed root.
            if (!root) return;
            root._parts = rows;
            var esp = -1;
            for (var i = 0; i < rows.length; i++) {
                if (rows[i].ptype.indexOf("EFI") !== -1) { esp = i; break; }
            }
            efiCombo.currentIndex = esp >= 0 ? esp : 0;
            var rootIdx = 0;
            for (var j = 0; j < rows.length; j++) {
                if (j !== esp) { rootIdx = j; break; }
            }
            rootCombo.currentIndex = rootIdx;
            root._syncRoot();
            root._syncEfi();
        });
    }

    function _syncRoot() {
        Cyber.WizState.rootPart = (root._parts.length > 0 && rootCombo.currentIndex >= 0)
            ? root._parts[rootCombo.currentIndex].dev : "";
    }
    function _syncEfi() {
        Cyber.WizState.efiPart = (root._parts.length > 0 && efiCombo.currentIndex >= 0)
            ? root._parts[efiCombo.currentIndex].dev : "";
    }

    Component.onCompleted: root.refresh()

    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Choose partitions"
            color: Cyber.Theme.fg
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 8; bold: true }
        }

        Text {
            width: parent.width
            text: "Partition the disk first with a tool like cfdisk if needed."
            color: Cyber.Theme.muted
            wrapMode: Text.WordWrap
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
        }

        Field {
            width: parent.width
            label: "Root (/)"
            subtitle: "Will be formatted"

            ComboBox {
                id: rootCombo
                width: 260
                height: 34
                enabled: root._parts.length > 0
                model: root._parts.length > 0
                       ? root._parts.map(function (p) { return p.label; })
                       : ["no partitions found"]
                onActivated: root._syncRoot()

                contentItem: Text {
                    text: rootCombo.displayText
                    color: Cyber.Theme.fg
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                    rightPadding: 24
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
                background: Rectangle {
                    implicitWidth: 260
                    implicitHeight: 34
                    radius: Cyber.Theme.radius / 2
                    color: Cyber.Theme.surface
                    border.width: 1
                    border.color: rootCombo.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                }
                indicator: Text {
                    x: rootCombo.width - width - 10
                    y: (rootCombo.height - height) / 2
                    text: "\uf0d7"
                    color: Cyber.Theme.muted
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
                }
                delegate: ItemDelegate {
                    width: rootCombo.width
                    highlighted: rootCombo.highlightedIndex === index
                    contentItem: Text {
                        text: modelData
                        color: Cyber.Theme.fg
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                    }
                    background: Rectangle {
                        color: highlighted ? Cyber.Theme.sel : Cyber.Theme.surface
                    }
                }
                popup: Popup {
                    y: rootCombo.height + 2
                    width: rootCombo.width
                    implicitHeight: Math.min(contentItem.implicitHeight, 200)
                    padding: 1

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: rootCombo.popup.visible ? rootCombo.delegateModel : null
                        currentIndex: rootCombo.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator {}
                    }
                    background: Rectangle {
                        color: Cyber.Theme.surface
                        border.width: 1
                        border.color: Cyber.Theme.border
                        radius: Cyber.Theme.radius / 2
                    }
                }
            }
        }

        Field {
            width: parent.width
            label: "EFI system partition"

            ComboBox {
                id: efiCombo
                width: 260
                height: 34
                enabled: root._parts.length > 0
                model: root._parts.length > 0
                       ? root._parts.map(function (p) { return p.label; })
                       : ["no partitions found"]
                onActivated: root._syncEfi()

                contentItem: Text {
                    text: efiCombo.displayText
                    color: Cyber.Theme.fg
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                    rightPadding: 24
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
                background: Rectangle {
                    implicitWidth: 260
                    implicitHeight: 34
                    radius: Cyber.Theme.radius / 2
                    color: Cyber.Theme.surface
                    border.width: 1
                    border.color: efiCombo.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                }
                indicator: Text {
                    x: efiCombo.width - width - 10
                    y: (efiCombo.height - height) / 2
                    text: "\uf0d7"
                    color: Cyber.Theme.muted
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
                }
                delegate: ItemDelegate {
                    width: efiCombo.width
                    highlighted: efiCombo.highlightedIndex === index
                    contentItem: Text {
                        text: modelData
                        color: Cyber.Theme.fg
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                    }
                    background: Rectangle {
                        color: highlighted ? Cyber.Theme.sel : Cyber.Theme.surface
                    }
                }
                popup: Popup {
                    y: efiCombo.height + 2
                    width: efiCombo.width
                    implicitHeight: Math.min(contentItem.implicitHeight, 200)
                    padding: 1

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: efiCombo.popup.visible ? efiCombo.delegateModel : null
                        currentIndex: efiCombo.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator {}
                    }
                    background: Rectangle {
                        color: Cyber.Theme.surface
                        border.width: 1
                        border.color: Cyber.Theme.border
                        radius: Cyber.Theme.radius / 2
                    }
                }
            }
        }

        Field {
            width: parent.width
            label: "Format the EFI partition"
            subtitle: "Leave off to keep another OS's bootloader"

            Rectangle {
                id: fmtTrack
                width: 44
                height: 24
                radius: 12
                color: Cyber.WizState.formatEfi ? Cyber.Theme.accent : Cyber.Theme.border

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: Cyber.Theme.surface
                    anchors.verticalCenter: parent.verticalCenter
                    x: Cyber.WizState.formatEfi ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Cyber.WizState.formatEfi = !Cyber.WizState.formatEfi
                }
            }
        }

        Hint {
            width: parent.width
            error: true
            text: root._problem()
        }
    }
}
