import QtQuick
import ".." as Cyber

// Ported verbatim from the GTK wizard's page_welcome(): same title, same
// two-paragraph message, same DRY RUN banner appended only when dry-run.
Item {
    id: root

    // Every page in this wizard follows this convention: shell.qml reads
    // these two off the Loader's current item to drive the Next button.
    property bool ready: true
    property string nextLabel: "Next"

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 560)
        spacing: 18

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Install CyberOS"
            color: Cyber.Theme.fg
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 10; bold: true }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.3
            text: "This will install CyberOS onto a disk in this machine.\n\n"
                  + "Everything on the disk you choose will be erased."
                  + (Cyber.WizState.dryRun ? "\n\nDRY RUN — nothing will be written." : "")
            color: Cyber.Theme.muted
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
        }
    }
}
