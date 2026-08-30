import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

RowLayout {
    id: tray
    spacing: 2
    property bool expanded: false

    BarModule {
        id: expander
        icon: expanded ? "\uf0da" : "\uf0d9"
        onClicked: tray.expanded = !tray.expanded
    }

    Row {
        visible: tray.expanded
        spacing: 4
        Repeater {
            model: SystemTray.items
            Item {
                required property var modelData
                width: 20; height: 20

                IconImage {
                    anchors.fill: parent
                    source: modelData.icon
                }
                QsMenuAnchor {
                    id: menuAnchor
                    menu: modelData.menu
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton && modelData.hasMenu)
                            menuAnchor.open();
                        else
                            modelData.activate();
                    }
                }
            }
        }
    }
}
