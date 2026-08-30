import QtQuick
import Quickshell
import ".." as Cyber

BarModule {
    id: clock
    property bool showDate: false
    // Glyph lives in `icon` (not baked into `label`) so `iconColor` actually
    // renders it in the theme accent -- BarModule's Row already spaces
    // icon and label 5px apart, so no manual leading space is needed here.
    icon: "\uf017"
    iconColor: Cyber.Theme.accent
    SystemClock { id: sys; precision: SystemClock.Minutes }
    // "HH:MM ddd", click flips to full date
    label: Qt.formatDateTime(sys.date, showDate ? "HH:mm yyyy-MM-dd" : "HH:mm ddd")
    onClicked: showDate = !showDate
}
