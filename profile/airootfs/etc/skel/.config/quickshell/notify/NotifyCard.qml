import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import ".." as Cyber

// One notification. appName/summary/body are attacker-controlled data (any
// app on the session bus can send them), so every Text here is forced to
// Text.PlainText -- same reasoning as bar/WindowTitle.qml and BarModule's
// label: Text's default AutoText would otherwise render HTML-like markup
// straight into the shell.
Rectangle {
    id: card

    required property var notification

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property bool hasImage: notification.image !== ""
    readonly property bool hasAppIcon: !hasImage && notification.appIcon !== ""

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 20
    radius: Cyber.Theme.radius / 2
    color: Cyber.Theme.surface
    border.width: critical ? 2 : 1
    border.color: critical ? Cyber.Theme.alert : Cyber.Theme.border

    // Background click-catcher, declared before the content below so the
    // action buttons (declared after, hence visually/input on top) get
    // first crack at their own clicks -- clicking anywhere else on the card
    // dismisses it.
    MouseArea {
        anchors.fill: parent
        onClicked: card.notification.dismiss()
    }

    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Image {
                visible: card.hasImage
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                fillMode: Image.PreserveAspectFit
                source: card.hasImage ? card.notification.image : ""
            }
            IconImage {
                visible: card.hasAppIcon
                implicitSize: 32
                source: card.hasAppIcon ? Quickshell.iconPath(card.notification.appIcon, "") : ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: card.notification.appName
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Cyber.Theme.muted
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 2 }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.notification.summary
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize; bold: true }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: card.notification.body
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            color: Cyber.Theme.fg
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: card.notification.actions.length > 0
            spacing: 6

            Repeater {
                model: card.notification.actions

                delegate: Rectangle {
                    required property var modelData
                    Layout.preferredHeight: 24
                    implicitWidth: label.implicitWidth + 16
                    radius: Cyber.Theme.radius / 2
                    color: actionMouse.containsMouse ? Cyber.Theme.sel : Cyber.Theme.bg
                    border.width: 1
                    border.color: Cyber.Theme.border

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.text
                        textFormat: Text.PlainText
                        color: Cyber.Theme.fg
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 2 }
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            modelData.invoke();
                            card.notification.dismiss();
                        }
                    }
                }
            }
        }
    }

    // Urgency: critical never auto-expires (the user must dismiss it); every
    // other notification expires after its own `expireTimeout` hint when the
    // sender set one (>0), else the same ~6s default mako used
    // (default-timeout=6000 in the old mako config).
    Timer {
        interval: card.notification.expireTimeout > 0 ? card.notification.expireTimeout : 6000
        running: !card.critical
        onTriggered: card.notification.expire()
    }
}
