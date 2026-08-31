pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Installer-local copy of the desktop shell's Theme (same property names,
// same fallback, same theme.json path) -- deliberate duplication so the
// installer renders correctly even when the shell's own Quickshell config is
// absent or broken (e.g. a fresh live ISO before ~/.config exists). Colours
// are defined in theme.json when present; the object below is only the
// fallback so a missing or broken theme.json degrades to a usable dark
// wizard instead of an invisible one.
Singleton {
    id: root

    property var t: fallback
    readonly property var fallback: ({
        mode: "dark", bg: "#1D1D1F", surface: "#2B2B2D", fg: "#F5F5F5",
        muted: "#C0BFC0", accent: "#00CA4E", accent2: "#FFBD44",
        alert: "#FF605C", border: "#3A3A3C", sel: "#3A3A3C", barAlpha: 0.88
    })

    readonly property color bg: t.bg
    readonly property color surface: t.surface
    readonly property color fg: t.fg
    readonly property color muted: t.muted
    readonly property color accent: t.accent
    readonly property color accent2: t.accent2
    readonly property color alert: t.alert
    readonly property color border: t.border
    readonly property color sel: t.sel
    readonly property string mode: t.mode
    readonly property real barAlpha: t.barAlpha
    readonly property bool dark: mode === "dark"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13
    readonly property int barHeight: 30
    readonly property int radius: 14

    FileView {
        // Quickshell.env() returns null for an unset var -- truthiness only,
        // never `!== ""` (see the shell's Theme.qml and tests/quickshell.bats
        // "C1" for the bug this avoids).
        path: {
            const c = Quickshell.env("XDG_CONFIG_HOME");
            return (c ? c : Quickshell.env("HOME") + "/.config") + "/quickshell/theme.json";
        }
        watchChanges: true
        // watchChanges only WATCHES: on a disk change FileView emits
        // fileChanged and leaves re-reading to us -- without this reload()
        // the wizard keeps its launch-time palette forever.
        onFileChanged: reload()
        onTextChanged: {
            try {
                const parsed = JSON.parse(text());
                if (parsed.bg !== undefined) root.t = parsed;
            } catch (e) { /* keep the last good palette */ }
        }
        onLoadFailed: root.t = root.fallback
    }
}
