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

    // Mirrors GTK's self.mode = "erase" default, set on the mode page's
    // radio group.
    property string mode: "erase"

    // The /dev path chosen on the disk page (self.disks[i][0] in the GTK
    // original -- the raw device name, never the display label).
    property string disk: ""

    // GiB of unallocated space on `disk`, as ModePage.qml's async
    // Probe.freeSpaceGib() calls resolve it -- refreshed whenever `mode` or
    // `disk` changes while the mode page is on screen. 0 until a probe
    // resolves, same starting value free_space_gib() would return on any
    // failure in the GTK original.
    property int freeGib: 0

    // ------------------------------------------------------ custom (manual)
    // Root/EFI picks from CustomPage.qml, manual mode only. /dev paths --
    // raw device names, never a picker's display label -- mirroring `disk`
    // above and the GTK original's part_devices[selected_index] (Wizard's
    // part_root/part_efi ComboRows only ever held the index; the actual
    // device string lived in self.part_devices). formatEfi defaults false,
    // matching Gtk.Switch's own default-inactive state (never set active
    // before use in page_custom()).
    property string rootPart: ""
    property string efiPart: ""
    property bool formatEfi: false

    // ------------------------------------------------------------ account
    // user/host default to the GTK EntryRow constructor defaults
    // (Adw.EntryRow(title="Username", text="student") /
    // Adw.EntryRow(title="Computer name", text="cyberos")); password has no
    // default -- Adw.PasswordEntryRow starts empty. Confirm-password is
    // deliberately NOT here: the GTK original never stored it past
    // validate_account()'s equality check either (e_pass2 lived only on the
    // page), so AccountPage.qml keeps it as page-local state.
    property string user: "student"
    property string host: "cyberos"
    property string password: ""

    // ------------------------------------------------------------ options
    // tz starts empty -- OptionsPage.qml sets it the moment Probe.timezones
    // resolves (Africa/Accra if present, else UTC), the same "pick a
    // default once probed data arrives" pattern DiskPage.qml already uses
    // for `disk`. fs/swapGib mirror the GTK ComboRow/SpinButton construction
    // defaults ("ext4", 4 -- Adw.ComboRow's first model entry / swap.set_value(4)).
    // encrypt defaults false, matching Adw.SwitchRow's own default-inactive
    // state (never set active before use in page_options()). luksPass has no
    // default for the same reason `password` doesn't -- PasswordEntryRow
    // starts empty; its confirm counterpart is page-local state for the same
    // reason the account page's is.
    property string tz: ""
    property string fs: "ext4"
    property int swapGib: 4
    property bool encrypt: false
    property string luksPass: ""

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
