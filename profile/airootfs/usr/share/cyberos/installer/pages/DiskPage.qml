import QtQuick
import QtQuick.Controls
import "."
import ".." as Cyber

// Ported verbatim from the GTK wizard's page_disk() (cyberos-install-gui,
// ~161): title "Choose a disk", one field row "Install to" / "The entire
// disk will be erased" holding a dropdown of Probe.disks -- Field.qml here
// stands in for the GTK original's Adw.PreferencesGroup + Adw.ComboRow.
// Probe.disks[i].label is already formatted exactly as page_disk() built it
// ("NAME  (SIZE)  MODEL[:22]"); "no disks found" is Probe.disks' own
// original toolkit's string-list fallback entry, ported as this page's ready-gate instead
// (the GTK ComboRow just showed the literal text with nothing selectable to
// act on -- Next disabled here achieves the same "cannot proceed" outcome).
Item {
    id: root

    property bool ready: Cyber.Probe.disks.length > 0
    property string nextLabel: "Next"

    // Default-select the first disk as soon as one is known, whether that
    // happens before this page is even shown (Probe already resolved) or
    // later while the page is on screen (Probe.disks arrives async).
    function _pickDefault() {
        if (Cyber.Probe.disks.length > 0 && !Cyber.WizState.disk) {
            Cyber.WizState.disk = Cyber.Probe.disks[0].name;
            diskCombo.currentIndex = 0;
        }
    }

    Component.onCompleted: root._pickDefault()
    Connections {
        target: Cyber.Probe
        function onDisksChanged() { root._pickDefault(); }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Choose a disk"
            color: Cyber.Theme.fg
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 8; bold: true }
        }

        Field {
            width: parent.width
            label: "Install to"
            subtitle: "The entire disk will be erased"

            ComboBox {
                id: diskCombo
                width: 260
                height: 34
                enabled: Cyber.Probe.disks.length > 0
                model: Cyber.Probe.disks.length > 0
                       ? Cyber.Probe.disks.map(function (d) { return d.label; })
                       : ["no disks found"]

                onActivated: function (index) {
                    if (Cyber.Probe.disks.length > 0)
                        Cyber.WizState.disk = Cyber.Probe.disks[index].name;
                }

                contentItem: Text {
                    text: diskCombo.displayText
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
                    border.color: diskCombo.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                }
                indicator: Text {
                    x: diskCombo.width - width - 10
                    y: (diskCombo.height - height) / 2
                    text: "\uf0d7"
                    color: Cyber.Theme.muted
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
                }
                delegate: ItemDelegate {
                    width: diskCombo.width
                    highlighted: diskCombo.highlightedIndex === index
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
                    y: diskCombo.height + 2
                    width: diskCombo.width
                    implicitHeight: Math.min(contentItem.implicitHeight, 200)
                    padding: 1

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: diskCombo.popup.visible ? diskCombo.delegateModel : null
                        currentIndex: diskCombo.highlightedIndex
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
    }
}
