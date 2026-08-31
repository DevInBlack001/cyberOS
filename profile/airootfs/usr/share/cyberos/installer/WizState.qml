pragma Singleton
import QtQuick
import Quickshell

// All wizard answers and navigation state, ported from the GTK Wizard class
// (cyberos-install-gui). No disk work happens here or anywhere in this
// config -- this singleton only accumulates the same answers the GTK wizard
// collected, for a later task's argv-building/install step to hand to
// `sudo -n cyberos-install ... --password-stdin --yes`.
Singleton {
    id: root

    // Quickshell.env() returns null for an unset var -- truthiness only,
    // never `!== ""`. Set by the wrapper (cyberos-install-gui --dry-run) via
    // `CYBEROS_INSTALLER_DRYRUN=1; export CYBEROS_INSTALLER_DRYRUN`.
    readonly property bool dryRun: Boolean(Quickshell.env("CYBEROS_INSTALLER_DRYRUN"))

    readonly property var pages: ["welcome", "disk", "mode", "custom", "account",
                                  "options", "confirm", "install", "done"]

    property int index: 0
    readonly property string page: pages[index]

    // Mirrors GTK's self.mode = "erase" default, set on the (later-task) mode
    // page's radio group.
    property string mode: "erase"

    // The partition picker is only meaningful for custom partitioning --
    // same rule as the GTK wizard's Wizard.skipped().
    function skipped(name) {
        return name === "custom" && mode !== "manual";
    }

    function next() {
        while (index < pages.length - 1) {
            index++;
            if (!skipped(page)) break;
        }
    }

    function back() {
        while (index > 0) {
            index--;
            if (!skipped(page)) break;
        }
    }
}
