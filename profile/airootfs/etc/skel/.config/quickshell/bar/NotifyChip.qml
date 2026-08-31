import QtQuick
import ".." as Cyber

// Bell + tracked-notification count; click toggles do-not-disturb. Bare
// `shell`/`notifServer` id references below resolve the same way
// bar/Battery.qml's `powerMenu.activeAsync` does -- see shell.qml's comment
// on Bar.Bar being instantiated inside ShellRoot via Variants, verified live
// (final-fix-report.md): every Bar.qml module lands in the same QML object
// scope as shell.qml's own ids/properties.
BarModule {
    id: chip

    readonly property int count: notifServer.trackedNotifications.values.length

    // fa-bell / fa-bell-slash (0xf0f3 / 0xf1f6) -- present in the shipped
    // JetBrainsMono Nerd Font's cmap (verified with fontTools against
    // /usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf).
    icon: shell.dnd ? "\uf1f6" : "\uf0f3"
    iconColor: shell.dnd ? Cyber.Theme.muted : (count > 0 ? Cyber.Theme.accent : Cyber.Theme.fg)
    label: (!shell.dnd && count > 0) ? String(count) : ""
    labelColor: Cyber.Theme.accent
    tooltip: shell.dnd ? "Do Not Disturb (click to re-enable)" : "Notifications (click for Do Not Disturb)"

    onClicked: shell.dnd = !shell.dnd
}
