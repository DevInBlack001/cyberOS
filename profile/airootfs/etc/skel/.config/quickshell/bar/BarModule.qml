import QtQuick
import ".." as Cyber

Rectangle {
    id: chip
    property string icon: ""
    property string label: ""
    property color iconColor: Cyber.Theme.fg
    property color labelColor: Cyber.Theme.fg
    property string tooltip: ""
    signal clicked(int button)
    signal scrolled(int delta)

    implicitWidth: row.implicitWidth + 14
    implicitHeight: Cyber.Theme.barHeight - 8
    radius: height / 2
    color: mouse.containsMouse ? Cyber.Theme.sel : "transparent"

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5
        Text { text: chip.icon; visible: chip.icon !== ""
               color: chip.iconColor
               font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize } }
        Text { text: chip.label; visible: chip.label !== ""
               color: chip.labelColor
               font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize } }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => chip.clicked(mouse.button)
        onWheel: wheel => chip.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
