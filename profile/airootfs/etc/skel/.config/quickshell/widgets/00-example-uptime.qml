// CyberOS example widget.
//
// Copy this file, rename it, make it yours. Any *.qml dropped into this
// directory (~/.config/quickshell/widgets/) appears on the bar automatically
// -- no edits to the shell itself, no restart beyond `hyprctl reload` (or
// just relaunch qs). Files load in filename order, so a numeric prefix like
// this one's "00-" controls where your widget lands relative to others.
//
// The root of a widget file can be any QtQuick Item. Bar.BarModule (the same
// chip class every built-in bar module uses) is recommended -- it gives you
// consistent padding, hover highlight, and click/scroll signals for free.
// You can also import Quickshell.Io for Process/StdioCollector to shell out,
// exactly as this example does with `uptime`.
import QtQuick
import Quickshell.Io
// Widgets live in ~/.config/quickshell/widgets/, one directory below the
// config root, so "../bar" reaches bar/ and ".." reaches the config root
// (Theme.qml et al.) the same way any other quickshell/*.qml file does.
import "../bar" as Bar
import ".." as Cyber

Bar.BarModule {
    id: widget
    // fa-clock_o. Nerd Font glyphs must be \uXXXX escapes, never raw
    // characters pasted into the file -- see the README and
    // tests/quickshell.bats's "no raw private-use glyphs" check.
    icon: "\uf017"
    // Cyber.Theme gives you the live palette (light/dark, re-themed on
    // Super+Shift+T) -- never hardcode a hex colour in a widget.
    iconColor: Cyber.Theme.accent

    Process {
        id: uptime
        command: ["sh", "-c", "cut -d. -f1 /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = parseInt(text);
                widget.label = Math.floor(s / 3600) + "h " + Math.floor(s % 3600 / 60) + "m";
            }
        }
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: uptime.running = true
    }
}
