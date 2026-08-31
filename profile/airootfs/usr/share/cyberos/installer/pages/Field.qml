import QtQuick
import QtQuick.Layouts
import ".." as Cyber

// Field.qml -- shared themed labelled row, the QML replacement for the GTK
// wizard's Adw.ActionRow/Adw.ComboRow (title + optional dim subtitle, plus a
// trailing control). Task 4's account/options pages reuse this for every
// labelled input row, so the API stays deliberately minimal:
//
//   Field { label: "Row title"; subtitle: "optional dim second line"
//       <exactly one control here, e.g. a ComboBox or a small indicator> }
//
// The control becomes the row's trailing content, sized to its own
// implicit size (via the `trailing` Item's childrenRect binding below) and
// placed to the right of the title/subtitle column. A whole-row click
// target (as ModePage.qml's radio rows need) is NOT built in here -- since
// Field is an opaque Rectangle, the caller adds a sibling MouseArea
// anchored to the same parent, on top of the Field in paint order.
Rectangle {
    id: root

    default property alias content: trailing.data
    property string label: ""
    property string subtitle: ""

    implicitHeight: Math.max(56, rowLayout.implicitHeight + 20)
    radius: Cyber.Theme.radius / 2
    color: Cyber.Theme.surface
    border.width: 1
    border.color: Cyber.Theme.border

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.label
                color: Cyber.Theme.fg
                wrapMode: Text.WordWrap
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize; bold: true }
            }
            Text {
                Layout.fillWidth: true
                text: root.subtitle
                visible: root.subtitle.length > 0
                wrapMode: Text.WordWrap
                color: Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 2 }
            }
        }

        Item {
            id: trailing
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
        }
    }
}
