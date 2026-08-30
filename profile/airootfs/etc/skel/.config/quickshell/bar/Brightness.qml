import QtQuick
import Quickshell
import Quickshell.Io
import ".." as Cyber

// Backlight chip. brightnessctl has no QML binding, so this reads/sets the
// level by shelling out -- the same "-m" CSV shape and field index (3) as
// shell.qml's OSD reader (~54-67), but via its OWN Process/StdioCollector:
// a bar-driven refresh must never race or interfere with the OSD's
// independent volumeUp/brightnessUp ipc flow, so nothing here is shared.
BarModule {
    id: brightness
    property int pct: 0
    property bool hasDevice: false
    visible: hasDevice

    // md-brightness_1..md-brightness_7, cmap-verified against the shipped
    // JetBrainsMono Nerd Font (fonttools method, see final-fix-report.md).
    // Index 5 (md-brightness_6, U+F00DF) is the same glyph shell.qml's OSD
    // reader already uses for the brightness icon.
    readonly property var levelIcons: [
        "\udb80\udcda", "\udb80\udcdb", "\udb80\udcdc", "\udb80\udcdd",
        "\udb80\udcde", "\udb80\udcdf", "\udb80\udce0"
    ]
    property int levelIdx: Math.max(0, Math.min(levelIcons.length - 1,
        Math.floor(pct / 100 * levelIcons.length)))

    icon: levelIcons[levelIdx]
    iconColor: Cyber.Theme.fg
    tooltip: pct + "%"

    Process {
        id: read
        command: ["brightnessctl", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = text.trim();
                const fields = trimmed.split(",");
                const p = parseInt(fields[3]);
                // Empty/unparseable output (no backlight device) hides the
                // chip; desktops have no backlight to show a level for.
                brightness.hasDevice = trimmed !== "" && !isNaN(p);
                if (!isNaN(p)) brightness.pct = p;
            }
        }
        // A non-zero exit (no backlight device present) always hides the
        // chip, regardless of what -- if anything -- landed on stdout.
        onExited: exitCode => { if (exitCode !== 0) brightness.hasDevice = false; }
    }

    onScrolled: delta => {
        Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", delta > 0 ? "5%+" : "5%-"]);
        read.running = true;
    }
}
