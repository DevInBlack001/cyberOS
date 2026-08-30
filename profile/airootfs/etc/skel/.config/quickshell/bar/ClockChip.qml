import QtQuick
import Quickshell
import ".." as Cyber

BarModule {
    id: clock
    property bool showDate: false
    iconColor: Cyber.Theme.accent
    SystemClock { id: sys; precision: SystemClock.Minutes }
    // "\uf017 HH:MM ddd", click flips to full date
    label: "\uf017 " + Qt.formatDateTime(sys.date, showDate ? "HH:mm yyyy-MM-dd" : "HH:mm ddd")
    onClicked: showDate = !showDate
}
