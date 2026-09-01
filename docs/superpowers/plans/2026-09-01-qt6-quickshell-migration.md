# GTK→Qt6/Quickshell Migration + Categorised Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove every GTK/GNOME desktop app and toolkit package from the CyberOS ISO, replace them with Qt6/KDE apps and native Quickshell panels (Wi-Fi, Bluetooth), and give the app launcher category chips (Security, Development, Internet, …).

**Architecture:** Package swap in `profile/packages.x86_64` (GNOME apps → KDE Gear Qt6 apps; `xdg-desktop-portal-gtk` → `xdg-desktop-portal-kde`); two new Quickshell popup surfaces built on the `Quickshell.Networking` / `Quickshell.Bluetooth` QML modules replace `nm-applet`/`nm-connection-editor`/`blueman`; the existing `launcher/Launcher.qml` grows a category-chip row driven by `DesktopEntry.categories`. GTK3 itself stays on the ISO as a transitive dependency of Firefox / VS Code — the goal is no GTK *apps or applets*, not a GTK-free dependency tree.

**Tech Stack:** archiso profile, Quickshell 0.3.1 (QML), Hyprland 0.56 Lua config, bats tests, KDE Gear 26.08 apps.

**Spec:** `docs/SPEC.md` (this plan also *edits* the spec: §5.7 store client changes from GTK4/libadwaita to Qt6/QML). The launcher/panel behaviour follows the conventions already established in `profile/airootfs/etc/skel/.config/quickshell/`.

## Global Constraints

- `main` is branch-protected (PR + review). All work happens on a new branch `desktop/qt6-apps`; the plan ends with a PR, never a push to main.
- Commits: `area: message` style (existing log: `shell:`, `tests:`, `installer:`). Author email must be `edbron411@gmail.com`.
- archiso copies `airootfs/` BEFORE pacstrap, so any airootfs file at a path owned by a package (non-backup) fails the build with "conflicting files". New files go under `/etc/skel`, `/usr/local/*`, or unowned `/etc` paths only. NEVER override an upstream `.desktop` by shipping a file at `/usr/share/applications/<name>.desktop`.
- bats: run as `bats tests/<file>.bats` from the repo root. A negated assertion must be written `run cmd; [ "$status" -ne 0 ]` — a bare `! cmd` is swallowed by bash errexit (regression fixed in commit 62fa455; do not reintroduce it).
- Claude cannot sudo. ISO rebuilds are run by the user: `sudo rm -rf work/iso && sudo mkarchiso -v -w work/iso -o out profile 2>&1 | tee work/build.log`.
- Quickshell QML API facts below were verified against `/usr/lib/qt6/qml/Quickshell/*/quickshell-*.qmltypes` for quickshell 0.3.1 on 2026-09-01 — trust them over guesses, and re-verify with `qs check` if quickshell is upgraded.
- Bar QML files contain Nerd Font private-use glyphs as `\udbXX\udcXX` escapes (safe to edit as text), but always use targeted `Edit` old/new replacements, never retype a whole file.
- The QEMU test VM has NO Wi-Fi and NO Bluetooth hardware: the new panels must render a sensible empty state there ("No Wi-Fi adapter" + wired status / "No Bluetooth adapter"). Full Wi-Fi/BT interaction can only be verified on a real laptop.
- Hyprland 0.56 Lua config: `hl.bind`, `hl.dsp.exec_cmd`, window rules as in the existing `hyprland.lua`. Tests drive it through `tests/hl-stub.lua` (`run_config` in `tests/hyprland-lua.bats`).

---

### Task 1: Package swap + spec §5.7

**Files:**
- Create: `tests/packages.bats`
- Modify: `profile/packages.x86_64` (lines 78–84, 156–204 regions)
- Modify: `docs/SPEC.md:330-339` (§5.7), `docs/SPEC.md:382-385` (§6.3 sentence)

**Interfaces:**
- Consumes: nothing (first task).
- Produces: the package set every later task assumes installed on the ISO: `dolphin`, `ark`, `kio-extras`, `kio-fuse`, `ffmpegthumbs`, `kdegraphics-thumbnailers`, `udisks2`, `pavucontrol-qt`, `kcalc`, `kate`, `okular`, `gwenview`, `partitionmanager`, `xdg-desktop-portal-kde`, `breeze-icons`, `adwaita-cursors`. All confirmed present in Arch repos on 2026-09-01 (KDE Gear 26.08).

- [ ] **Step 0: Create the working branch**

```bash
cd ~/Work/cyberos
git checkout main && git pull
git checkout -b desktop/qt6-apps
```

- [ ] **Step 1: Write the failing test**

Create `tests/packages.bats`:

```bash
#!/usr/bin/env bats
# GTK purge: packages.x86_64 must not list GTK/GNOME desktop apps/applets,
# and must list their Qt6/KDE replacements. GTK3 itself may still arrive as
# a dependency of firefox/code -- that is fine and not tested here.

PKGS="$BATS_TEST_DIRNAME/../profile/packages.x86_64"

# Exact-name match against the package list with comments stripped.
pkg_listed() {
  sed 's/#.*//' "$PKGS" | tr -d ' ' | grep -v '^$' | grep -qx "$1"
}

@test "no GTK/GNOME packages remain in packages.x86_64" {
  for p in gtk4 libadwaita xdg-desktop-portal-gtk network-manager-applet \
           blueman pavucontrol thunar thunar-archive-plugin thunar-volman \
           gvfs gvfs-mtp file-roller tumbler imv zathura zathura-pdf-mupdf \
           gnome-calculator gnome-text-editor gnome-disk-utility nwg-look \
           adwaita-icon-theme gnome-themes-extra; do
    run pkg_listed "$p"
    [ "$status" -ne 0 ]
  done
}

@test "Qt6/KDE replacements are present in packages.x86_64" {
  for p in dolphin ark kio-extras kio-fuse ffmpegthumbs \
           kdegraphics-thumbnailers udisks2 pavucontrol-qt kcalc kate okular \
           gwenview partitionmanager xdg-desktop-portal-kde breeze-icons \
           adwaita-cursors; do
    pkg_listed "$p"
  done
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bats tests/packages.bats`
Expected: FAIL — both tests (GTK packages still listed, replacements absent).

- [ ] **Step 3: Edit `profile/packages.x86_64`**

Apply these changes (targeted edits, keep surrounding comments coherent):

1. Delete the whole `# ---- GTK4/libadwaita stack ----` section (lines 78–84: the comment block plus `gtk4` and `libadwaita`). The §5.7 earmark is being retired in this same task.
2. In `# ---- network ----`: delete `network-manager-applet` (the Quickshell Wi-Fi panel replaces it — Task 4).
3. In `# ---- Hyprland desktop ----`: delete `xdg-desktop-portal-gtk` and `nwg-look`; add directly below `xdg-desktop-portal-hyprland`:

```
# Qt file-chooser/settings portal -- hyprland's portal has no FileChooser.
# Replaces xdg-desktop-portal-gtk; /etc/xdg-desktop-portal/hyprland-portals.conf
# routes FileChooser here.
xdg-desktop-portal-kde
```

4. In `# ---- audio / bluetooth ----`: replace `pavucontrol` with `pavucontrol-qt`; delete `blueman` (Quickshell Bluetooth panel replaces it — Task 5).
5. Replace the whole `# ---- apps ----` section body (keep `firefox` first) with:

```
# ---- apps ----
firefox
# Qt6/KDE app suite -- GTK apps (thunar, file-roller, gnome-*) are gone.
dolphin
ark
# kio-extras: MTP/SMB/etc URLs in dolphin; kio-fuse: lets non-KDE apps open
# kio URLs; udisks2: removable-drive mounting via Solid.
kio-extras
kio-fuse
udisks2
# video + document thumbnails in dolphin
ffmpegthumbs
kdegraphics-thumbnailers
gwenview
mpv
okular
kcalc
kate
partitionmanager
```

   (`imv`, `zathura`, `zathura-pdf-mupdf`, `gnome-calculator`, `gnome-text-editor`, `gnome-disk-utility`, `thunar`, `thunar-archive-plugin`, `thunar-volman`, `gvfs`, `gvfs-mtp`, `file-roller`, `tumbler` all disappear in this rewrite; `mpv` survives.)
6. In `# ---- fonts / theme ----`: replace `adwaita-icon-theme` with `adwaita-cursors` (cursor theme only — Papirus stays the icon theme) and `gnome-themes-extra` with `breeze-icons` (icon fallback for KDE apps; GTK3's Adwaita/Adwaita-dark are built into gtk3 itself, so `gnome-themes-extra` is dead weight).

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `bats tests/packages.bats`
Expected: PASS (2 tests).

- [ ] **Step 5: Update `docs/SPEC.md` §5.7**

Replace (at `docs/SPEC.md:332-334`):

```
`cyberos-store` — a CLI plus a GTK4/libadwaita GUI. `gtk4`/`libadwaita` are already in
`packages.x86_64` for this (the installer is now a CLI and no longer needs them; add
`python-gobject` back alongside this client if it's written in Python). It reads an
```

with:

```
`cyberos-store` — a CLI plus a Qt6/QML GUI (QtQuick, the same toolkit as the shell;
`qt6-declarative` is already on the ISO. Add `pyside6` alongside this client if it's
written in Python). It reads an
```

- [ ] **Step 6: Update `docs/SPEC.md` §6.3**

Replace (at `docs/SPEC.md:382-384`):

```
Automating this is Plan 3, Task 5. The GUI wizard is checked by
`cyberos-install-gui --dry-run` plus a manual pass, because driving GTK through QEMU
`sendkey` has already proven unreliable.
```

with:

```
Automating this is Plan 3, Task 5. The installer is CLI-only (the former GTK wizard
and its dry-run check are gone), so the whole flow is scriptable over `sendkey`.
```

- [ ] **Step 7: Commit**

```bash
git add tests/packages.bats profile/packages.x86_64 docs/SPEC.md
git commit -m "packages: GTK/GNOME apps out, Qt6/KDE suite in"
```

---

### Task 2: Desktop plumbing — portal config, mimeapps, xfce/gtk4 config removal

**Files:**
- Create: `tests/qt-desktop.bats`
- Create: `profile/airootfs/etc/xdg-desktop-portal/hyprland-portals.conf`
- Create: `profile/airootfs/etc/skel/.config/mimeapps.list`
- Delete: `profile/airootfs/etc/skel/.config/xfce4/` (dir), `profile/airootfs/usr/share/xfce4/` (dir), `profile/airootfs/etc/skel/.local/share/applications/xfce4-about.desktop`, `profile/airootfs/etc/skel/.config/gtk-4.0/` (dir)
- Keep untouched: `profile/airootfs/etc/skel/.config/gtk-3.0/settings.ini` (Firefox/Electron still read it; GTK3's Adwaita-dark is built in, `gtk-cursor-theme-name=Adwaita` is satisfied by `adwaita-cursors`).

**Interfaces:**
- Consumes: package set from Task 1 (`xdg-desktop-portal-kde`, KDE apps whose `.desktop` ids the mimeapps file names).
- Produces: default-app routing later tasks and VM verification rely on: PDFs→`okularApplication_pdf.desktop`, images→`org.kde.gwenview.desktop`, dirs→`org.kde.dolphin.desktop`, text→`org.kde.kate.desktop`, archives→`org.kde.ark.desktop`.

- [ ] **Step 1: Write the failing test**

Create `tests/qt-desktop.bats`:

```bash
#!/usr/bin/env bats
# Qt desktop plumbing: portal routing, default apps, and the absence of the
# old thunar/xfce helper and GTK4 config files.

AIROOTFS="$BATS_TEST_DIRNAME/../profile/airootfs"

@test "portal config: hyprland first, kde FileChooser, no gtk" {
  f="$AIROOTFS/etc/xdg-desktop-portal/hyprland-portals.conf"
  [ -f "$f" ]
  grep -qx 'default=hyprland;kde' "$f"
  grep -qx 'org.freedesktop.impl.portal.FileChooser=kde' "$f"
  run grep 'gtk' "$f"
  [ "$status" -ne 0 ]
}

@test "mimeapps.list routes documents to the Qt apps" {
  f="$AIROOTFS/etc/skel/.config/mimeapps.list"
  grep -qx 'application/pdf=okularApplication_pdf.desktop' "$f"
  grep -qx 'image/png=org.kde.gwenview.desktop' "$f"
  grep -qx 'inode/directory=org.kde.dolphin.desktop' "$f"
  grep -qx 'text/plain=org.kde.kate.desktop' "$f"
  grep -qx 'application/zip=org.kde.ark.desktop' "$f"
  grep -qx 'x-scheme-handler/https=firefox.desktop' "$f"
}

@test "xfce helper and gtk-4.0 configs are gone; gtk-3.0 stays for firefox" {
  [ ! -e "$AIROOTFS/etc/skel/.config/xfce4" ]
  [ ! -e "$AIROOTFS/usr/share/xfce4" ]
  [ ! -e "$AIROOTFS/etc/skel/.local/share/applications/xfce4-about.desktop" ]
  [ ! -e "$AIROOTFS/etc/skel/.config/gtk-4.0" ]
  [ -f "$AIROOTFS/etc/skel/.config/gtk-3.0/settings.ini" ]
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bats tests/qt-desktop.bats`
Expected: FAIL — all 3 tests.

- [ ] **Step 3: Create the portal config**

Create `profile/airootfs/etc/xdg-desktop-portal/hyprland-portals.conf`:

```
[preferred]
default=hyprland;kde
org.freedesktop.impl.portal.FileChooser=kde
```

(`/etc/xdg-desktop-portal/` beats the hyprland package's `/usr/share/xdg-desktop-portal/hyprland-portals.conf`, which prefers the now-absent gtk portal.)

- [ ] **Step 4: Create the mimeapps file**

Create `profile/airootfs/etc/skel/.config/mimeapps.list`:

```
[Default Applications]
application/pdf=okularApplication_pdf.desktop
image/png=org.kde.gwenview.desktop
image/jpeg=org.kde.gwenview.desktop
image/gif=org.kde.gwenview.desktop
image/webp=org.kde.gwenview.desktop
image/svg+xml=org.kde.gwenview.desktop
inode/directory=org.kde.dolphin.desktop
text/plain=org.kde.kate.desktop
application/zip=org.kde.ark.desktop
application/x-7z-compressed=org.kde.ark.desktop
application/x-tar=org.kde.ark.desktop
application/gzip=org.kde.ark.desktop
video/mp4=mpv.desktop
video/x-matroska=mpv.desktop
video/webm=mpv.desktop
audio/mpeg=mpv.desktop
audio/flac=mpv.desktop
text/html=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop
```

- [ ] **Step 5: Delete the thunar/xfce/gtk4 config files**

```bash
git rm -r profile/airootfs/etc/skel/.config/xfce4 \
          profile/airootfs/usr/share/xfce4 \
          profile/airootfs/etc/skel/.local/share/applications/xfce4-about.desktop \
          profile/airootfs/etc/skel/.config/gtk-4.0
```

- [ ] **Step 6: Run the tests and make sure they pass**

Run: `bats tests/qt-desktop.bats`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add tests/qt-desktop.bats profile/airootfs/etc/xdg-desktop-portal profile/airootfs/etc/skel/.config/mimeapps.list
git commit -m "desktop: kde portal + Qt default apps; xfce/gtk4 config gone"
```

---

### Task 3: hyprland.lua — dolphin, no GTK applets, direct installer launch

**Files:**
- Modify: `profile/airootfs/etc/skel/.config/hypr/hyprland.lua:22,31-32,110,165`
- Modify: `profile/airootfs/usr/local/bin/cyberos-install:791`
- Modify: `tests/hyprland-lua.bats:91-99` (autostart test) plus any assertion matching `gtk-launch`/`thunar`

**Interfaces:**
- Consumes: package set from Task 1 (`dolphin`, `pavucontrol-qt`, `kcalc`).
- Produces: the Super+I bind line whose exec starts with `foot --app-id=cyberos-installer` — the installer's post-install sed (below) and Task 6's InstallButton use the same command string.

- [ ] **Step 1: Update the failing tests first**

In `tests/hyprland-lua.bats`, rewrite the autostart test (currently at lines 91–99):

```bash
@test "autostart execs qs exactly once; swaybg/cliphist survive; GTK applets gone" {
  run run_config
  [ "$status" -eq 0 ]
  n=$(grep -c '^exec qs$' <<<"$output")
  [ "$n" -eq 1 ]
  [[ "$output" == *"exec swaybg"* ]]
  [[ "$output" != *"nm-applet"* ]]
  [[ "$output" != *"blueman-applet"* ]]
  [[ "$output" == *"exec wl-paste --type text --watch cliphist store"* ]]
  [[ "$output" == *"exec wl-paste --type image --watch cliphist store"* ]]
}
```

Then `grep -n 'gtk-launch\|thunar\|pavucontrol\|blueman\|nm-connection\|gnome' tests/hyprland-lua.bats` and update every hit to the new values:
- Super+E bind assertion (if present) becomes: `[[ "$output" == *"bindcmd SUPER + E :: dolphin"* ]]`
- Super+I bind assertion (if present) becomes: `[[ "$output" == *'bindcmd SUPER + I :: foot --app-id=cyberos-installer --title="Install CyberOS" sudo /usr/local/bin/cyberos-install'* ]]`
- Float-rule assertion (if present) now expects class regex `^(pavucontrol-qt|org.kde.kcalc)$`.

If no such assertions exist yet, add this test after the autostart one:

```bash
@test "app binds target the Qt apps; installer launches without gtk-launch" {
  run run_config
  [[ "$output" == *"bindcmd SUPER + E :: dolphin"* ]]
  [[ "$output" == *'bindcmd SUPER + I :: foot --app-id=cyberos-installer --title="Install CyberOS" sudo /usr/local/bin/cyberos-install'* ]]
  [[ "$output" != *"gtk-launch"* ]]
}
```

- [ ] **Step 2: Run to make sure the updated tests fail**

Run: `bats tests/hyprland-lua.bats`
Expected: the rewritten autostart test and the new binds test FAIL; the rest still pass.

- [ ] **Step 3: Edit `hyprland.lua`**

Four targeted edits:

1. Line 22: `local files    = "thunar"` → `local files    = "dolphin"`
2. Delete lines 31–32 (`hl.exec_cmd("nm-applet --indicator")` and `hl.exec_cmd("blueman-applet")`). The bar's Network/Bluetooth chips + the Task 4/5 panels replace them.
3. Line 110: replace

```lua
hl.bind(mod .. " + I",      hl.dsp.exec_cmd("gtk-launch cyberos-install"))
```

with

```lua
-- gtk-launch is gone with GTK; exec the installer .desktop's command directly.
hl.bind(mod .. " + I",      hl.dsp.exec_cmd('foot --app-id=cyberos-installer --title="Install CyberOS" sudo /usr/local/bin/cyberos-install'))
```

4. Line 165 window rule: replace

```lua
  match = { class = "^(pavucontrol|blueman-manager|nm-connection-editor|org.gnome.Calculator)$" },
```

with

```lua
  match = { class = "^(pavucontrol-qt|org.kde.kcalc)$" },
```

- [ ] **Step 4: Update the installer's post-install sed**

`profile/airootfs/usr/local/bin/cyberos-install:791` currently strips the live-only Super+I bind by pattern:

```bash
sed -i '/gtk-launch cyberos-install/d' /etc/skel/.config/hypr/hyprland.lua /home/*/.config/hypr/hyprland.lua 2>/dev/null || true
```

Replace with (pattern matches ONLY the bind line — the `float-installer` window rule contains `cyberos-installer` too but not `foot --app-id=`):

```bash
sed -i '\#foot --app-id=cyberos-installer#d' /etc/skel/.config/hypr/hyprland.lua /home/*/.config/hypr/hyprland.lua 2>/dev/null || true
```

- [ ] **Step 5: Run the tests and make sure they pass**

Run: `bats tests/hyprland-lua.bats tests/installer-cli.bats`
Expected: PASS (installer-cli.bats guards against regressions from the sed edit).

- [ ] **Step 6: Commit**

```bash
git add profile/airootfs/etc/skel/.config/hypr/hyprland.lua profile/airootfs/usr/local/bin/cyberos-install tests/hyprland-lua.bats
git commit -m "hypr: dolphin as file manager, GTK applets and gtk-launch removed"
```

---

### Task 4: Quickshell Wi-Fi panel (replaces nm-applet / nm-connection-editor)

**Files:**
- Create: `profile/airootfs/etc/skel/.config/quickshell/popups/WifiPanel.qml`
- Modify: `profile/airootfs/etc/skel/.config/quickshell/shell.qml` (LazyLoader + IpcHandler)
- Modify: `profile/airootfs/etc/skel/.config/quickshell/bar/Network.qml:31` (click target)
- Modify: `tests/quickshell.bats` (new test)

**Interfaces:**
- Consumes: `Quickshell.Networking` (verified 0.3.1 API): singleton `Networking` with `devices` (UntypedObjectModel), `wifiEnabled: bool` (writable), `wifiHardwareEnabled: bool`; `NetworkDevice { type, name, networks, connected, state }`; `WifiDevice : NetworkDevice { scannerEnabled: bool (writable) }`; `WifiNetwork : Network { signalStrength: double (0–100), security: WifiSecurityType }`; `Network { name, connected, known, state, connect(), disconnect(), forget(), connectWithPsk(psk) }`; enums `DeviceType.{None,Wifi,Wired}`, `WifiSecurityType.{Open,Owe,WpaPsk,Wpa2Psk,Sae,…}`, `ConnectionState.{Unknown,Connecting,Connected,Disconnecting,Disconnected}`. Also the `PanelWindow` + `closeRequested` + LazyLoader/IpcHandler pattern from `launcher/Launcher.qml` and `shell.qml`.
- Produces: IPC target `wifi` with `toggle()` — used by `bar/Network.qml` (this task). Panel file name `popups/WifiPanel.qml`, component `WifiPanel`.

- [ ] **Step 1: Write the failing test**

Append to `tests/quickshell.bats`:

```bash
@test "wifi panel replaces nm-applet: surface, ipc target, chip click" {
  [ -f "$QS/popups/WifiPanel.qml" ]
  grep -q 'Quickshell.Networking' "$QS/popups/WifiPanel.qml"
  grep -q 'connectWithPsk' "$QS/popups/WifiPanel.qml"
  grep -q 'scannerEnabled' "$QS/popups/WifiPanel.qml"
  grep -q 'target: "wifi"' "$QS/shell.qml"
  grep -q 'qs ipc call wifi toggle\|"wifi", "toggle"' "$QS/bar/Network.qml"
  run grep 'nm-connection-editor' "$QS/bar/Network.qml"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bats tests/quickshell.bats`
Expected: the new test FAILS (file missing); existing tests pass.

- [ ] **Step 3: Create `popups/WifiPanel.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import ".." as Cyber

// Wi-Fi panel -- replaces nm-applet + nm-connection-editor. Opened/closed
// via `qs ipc call wifi toggle` (LazyLoader in shell.qml), created fresh on
// every open like Launcher.qml, so per-open state (the inline password
// prompt) resets for free. QEMU VMs have no Wi-Fi device: the panel then
// shows the wired status line and a "No Wi-Fi adapter" placeholder.
PanelWindow {
    id: root

    signal closeRequested()

    anchors { top: true; right: true }
    margins { top: 44; right: 8 }
    implicitWidth: 360
    implicitHeight: 440
    color: "transparent"
    focusable: true
    aboveWindows: true

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    // Connected network first, then by signal strength.
    readonly property var networks: {
        const list = (wifiDevice?.networks.values ?? []).slice();
        return list.sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength));
    }
    // Name of the network whose inline password prompt is open ("" = none).
    property string pskFor: ""

    // Scan only while the panel is open.
    Component.onCompleted: if (wifiDevice) wifiDevice.scannerEnabled = true
    Component.onDestruction: if (wifiDevice) wifiDevice.scannerEnabled = false

    function needsPsk(net) {
        return !net.known
            && (net.security === WifiSecurityType.WpaPsk
             || net.security === WifiSecurityType.Wpa2Psk
             || net.security === WifiSecurityType.Sae);
    }
    function activate(net) {
        if (net.connected)      { net.disconnect(); return; }
        if (root.needsPsk(net)) { root.pskFor = net.name; return; }
        net.connect();
    }

    Rectangle {
        anchors.fill: parent
        radius: Cyber.Theme.radius
        color: Cyber.Theme.bg
        border.width: 1
        border.color: Cyber.Theme.border

        focus: true
        Keys.onEscapePressed: root.closeRequested()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Wi-Fi"
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 2; bold: true }
                }
                Item { Layout.fillWidth: true }
                Switch {
                    checked: Networking.wifiEnabled
                    enabled: Networking.wifiHardwareEnabled
                    onToggled: Networking.wifiEnabled = checked
                }
            }

            Text {
                visible: root.wiredDevice !== null
                text: (root.wiredDevice?.connected ?? false) ? "Wired: connected" : "Wired: no link"
                color: (root.wiredDevice?.connected ?? false) ? Cyber.Theme.accent : Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
            }

            Text {
                visible: root.wifiDevice === null
                text: "No Wi-Fi adapter"
                color: Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: ScriptModel {
                    values: root.networks
                    comparisonMode: ObjectComparison.Identity
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: list.width
                    height: pskField.visible ? 72 : 40
                    radius: Cyber.Theme.radius / 2
                    color: rowMouse.containsMouse ? Cyber.Theme.sel : "transparent"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                color: row.modelData.connected ? Cyber.Theme.accent : Cyber.Theme.fg
                                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                                elide: Text.ElideRight
                            }
                            Text {
                                // lock glyph for secured networks (FontAwesome nf-fa-lock)
                                visible: row.modelData.security !== WifiSecurityType.Open
                                      && row.modelData.security !== WifiSecurityType.Owe
                                text: ""
                                color: Cyber.Theme.muted
                                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 2 }
                            }
                            Text {
                                text: row.modelData.state === ConnectionState.Connecting
                                    ? "…" : Math.round(row.modelData.signalStrength) + "%"
                                color: Cyber.Theme.muted
                                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 2 }
                            }
                        }

                        TextField {
                            id: pskField
                            Layout.fillWidth: true
                            visible: root.pskFor === row.modelData.name
                            placeholderText: "Password"
                            placeholderTextColor: Cyber.Theme.muted
                            color: Cyber.Theme.fg
                            echoMode: TextInput.Password
                            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                            background: Rectangle {
                                color: Cyber.Theme.surface
                                radius: Cyber.Theme.radius / 2
                                border.width: 1
                                border.color: Cyber.Theme.border
                            }
                            onVisibleChanged: if (visible) forceActiveFocus()
                            onAccepted: {
                                row.modelData.connectWithPsk(text);
                                root.pskFor = "";
                            }
                            Keys.onEscapePressed: root.pskFor = ""
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        // Let clicks reach the password field when it is open.
                        enabled: !pskField.visible
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (row.modelData.known) row.modelData.forget();
                            } else {
                                root.activate(row.modelData);
                            }
                        }
                    }
                }
            }

            Text {
                text: "Click to connect · right-click to forget · Esc to close"
                color: Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 3 }
            }
        }
    }
}
```

- [ ] **Step 4: Wire it into `shell.qml`**

After the `clip` LazyLoader (line 64–67), add:

```qml
    LazyLoader {
        id: wifi
        Popups.WifiPanel { onCloseRequested: wifi.active = false }
    }
```

After the `clip` IpcHandler (line 152–157), add:

```qml
    // `qs ipc call wifi toggle` -- replaces nm-applet/nm-connection-editor.
    IpcHandler {
        target: "wifi"
        function toggle(): void {
            wifi.activeAsync ? wifi.active = false : wifi.activeAsync = true
        }
    }
```

- [ ] **Step 5: Retarget the bar chip**

In `bar/Network.qml`, replace line 31:

```qml
    onClicked: Quickshell.execDetached(["nm-connection-editor"])
```

with:

```qml
    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "wifi", "toggle"])
```

- [ ] **Step 6: Syntax-check and run the tests**

Run: `qs check -p profile/airootfs/etc/skel/.config/quickshell 2>&1 | head -30` (0 errors expected; if `qs check` lacks `-p` on this version, run `QT_QPA_PLATFORM=offscreen qs -p <path> -n` briefly), then `bats tests/quickshell.bats`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add profile/airootfs/etc/skel/.config/quickshell tests/quickshell.bats
git commit -m "shell: QML Wi-Fi panel replaces nm-applet and nm-connection-editor"
```

---

### Task 5: Quickshell Bluetooth panel (replaces blueman)

**Files:**
- Create: `profile/airootfs/etc/skel/.config/quickshell/popups/BluetoothPanel.qml`
- Modify: `profile/airootfs/etc/skel/.config/quickshell/shell.qml` (LazyLoader + IpcHandler)
- Modify: `profile/airootfs/etc/skel/.config/quickshell/bar/BluetoothChip.qml:15` (click target)
- Modify: `tests/quickshell.bats` (new test)

**Interfaces:**
- Consumes: `Quickshell.Bluetooth` (verified 0.3.1 API): singleton `Bluetooth` with `defaultAdapter`; `BluetoothAdapter { name, enabled: bool (writable), state, discovering: bool (writable), devices }`; `BluetoothDevice { name, deviceName, address, icon, state, connected, paired, bonded, pairing, trusted, blocked, batteryAvailable, battery, connect(), disconnect(), pair(), cancelPair(), forget() }`; `BluetoothDeviceState.{Disconnected,Connected,Disconnecting,Connecting}`. Plus the same LazyLoader/IpcHandler pattern.
- Produces: IPC target `bt` with `toggle()` — used by `bar/BluetoothChip.qml` (this task).

- [ ] **Step 1: Write the failing test**

Append to `tests/quickshell.bats`:

```bash
@test "bluetooth panel replaces blueman: surface, ipc target, chip click" {
  [ -f "$QS/popups/BluetoothPanel.qml" ]
  grep -q 'Quickshell.Bluetooth' "$QS/popups/BluetoothPanel.qml"
  grep -q 'pair()' "$QS/popups/BluetoothPanel.qml"
  grep -q 'target: "bt"' "$QS/shell.qml"
  grep -q '"bt", "toggle"' "$QS/bar/BluetoothChip.qml"
  run grep 'blueman' "$QS/bar/BluetoothChip.qml"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bats tests/quickshell.bats`
Expected: the new test FAILS; the rest pass.

- [ ] **Step 3: Create `popups/BluetoothPanel.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import ".." as Cyber

// Bluetooth panel -- replaces blueman-manager/blueman-applet. Opened via
// `qs ipc call bt toggle`, fresh instance per open (Launcher.qml pattern).
// QEMU VMs expose no adapter: the panel shows "No Bluetooth adapter".
PanelWindow {
    id: root

    signal closeRequested()

    anchors { top: true; right: true }
    margins { top: 44; right: 8 }
    implicitWidth: 340
    implicitHeight: 420
    color: "transparent"
    focusable: true
    aboveWindows: true

    readonly property var adapter: Bluetooth.defaultAdapter
    // Connected first, then paired, then by name.
    readonly property var devices: {
        const list = (adapter?.devices.values ?? []).slice();
        return list.sort((a, b) => (b.connected - a.connected)
            || (b.paired - a.paired)
            || (a.name ?? "").localeCompare(b.name ?? ""));
    }

    // Discover while the panel is open (only when the radio is on).
    Component.onCompleted: if (adapter && adapter.enabled) adapter.discovering = true
    Component.onDestruction: if (adapter) adapter.discovering = false

    function activate(dev) {
        if (dev.connected)    { dev.disconnect(); return; }
        if (dev.pairing)      { dev.cancelPair(); return; }
        if (dev.paired || dev.bonded) { dev.connect(); return; }
        dev.pair();
    }
    function statusText(dev) {
        if (dev.pairing) return "pairing…";
        if (dev.state === BluetoothDeviceState.Connecting) return "connecting…";
        if (dev.connected) return dev.batteryAvailable
            ? "connected · " + Math.round(dev.battery * 100) + "%" : "connected";
        return dev.paired || dev.bonded ? "paired" : "";
    }

    Rectangle {
        anchors.fill: parent
        radius: Cyber.Theme.radius
        color: Cyber.Theme.bg
        border.width: 1
        border.color: Cyber.Theme.border

        focus: true
        Keys.onEscapePressed: root.closeRequested()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Bluetooth"
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 2; bold: true }
                }
                Item { Layout.fillWidth: true }
                Switch {
                    enabled: root.adapter !== null
                    checked: root.adapter?.enabled ?? false
                    onToggled: if (root.adapter) {
                        root.adapter.enabled = checked;
                        if (checked) root.adapter.discovering = true;
                    }
                }
            }

            Text {
                visible: root.adapter === null
                text: "No Bluetooth adapter"
                color: Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
            }

            Text {
                visible: (root.adapter?.discovering ?? false)
                text: "Scanning…"
                color: Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 2 }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: ScriptModel {
                    values: root.devices
                    comparisonMode: ObjectComparison.Identity
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: list.width
                    height: 40
                    radius: Cyber.Theme.radius / 2
                    color: rowMouse.containsMouse ? Cyber.Theme.sel : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name || row.modelData.deviceName || row.modelData.address
                            color: row.modelData.connected ? Cyber.Theme.accent : Cyber.Theme.fg
                            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                            elide: Text.ElideRight
                        }
                        Text {
                            text: root.statusText(row.modelData)
                            color: Cyber.Theme.muted
                            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 2 }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (row.modelData.paired || row.modelData.bonded) row.modelData.forget();
                            } else {
                                root.activate(row.modelData);
                            }
                        }
                    }
                }
            }

            Text {
                text: "Click to connect/pair · right-click to forget · Esc to close"
                color: Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 3 }
            }
        }
    }
}
```

- [ ] **Step 4: Wire it into `shell.qml`**

Next to the Task-4 `wifi` LazyLoader, add:

```qml
    LazyLoader {
        id: bt
        Popups.BluetoothPanel { onCloseRequested: bt.active = false }
    }
```

Next to the `wifi` IpcHandler, add:

```qml
    // `qs ipc call bt toggle` -- replaces blueman-manager/blueman-applet.
    IpcHandler {
        target: "bt"
        function toggle(): void {
            bt.activeAsync ? bt.active = false : bt.activeAsync = true
        }
    }
```

- [ ] **Step 5: Retarget the bar chip**

In `bar/BluetoothChip.qml`, replace line 15:

```qml
    onClicked: Quickshell.execDetached(["blueman-manager"])
```

with:

```qml
    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "bt", "toggle"])
```

- [ ] **Step 6: Syntax-check and run the tests**

Run: same `qs check` invocation as Task 4 Step 6, then `bats tests/quickshell.bats`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add profile/airootfs/etc/skel/.config/quickshell tests/quickshell.bats
git commit -m "shell: QML Bluetooth panel replaces blueman"
```

---

### Task 6: Remaining chip retargets — pavucontrol-qt and the install button

**Files:**
- Modify: `profile/airootfs/etc/skel/.config/quickshell/bar/Audio.qml:21`
- Modify: `profile/airootfs/etc/skel/.config/quickshell/bar/InstallButton.qml:23`
- Modify: `tests/quickshell.bats:44-47` (audio test)

**Interfaces:**
- Consumes: `pavucontrol-qt` package (Task 1); installer exec string from Task 3 (`foot --app-id=cyberos-installer --title=Install CyberOS sudo /usr/local/bin/cyberos-install`).
- Produces: nothing later tasks use.

- [ ] **Step 1: Update the failing test first**

In `tests/quickshell.bats`, the audio test currently asserts `grep -q 'pavucontrol' "$QS/bar/Audio.qml"`. Replace that line with:

```bash
  grep -q 'pavucontrol-qt' "$QS/bar/Audio.qml"
```

and append a new test:

```bash
@test "no GTK launch paths remain anywhere in the shell" {
  run grep -R 'gtk-launch\|blueman\|nm-applet\|nm-connection-editor' "$QS"
  [ "$status" -ne 0 ]
  run grep -RE '\bpavucontrol\b' "$QS"   # bare pavucontrol (the GTK app)
  [ "$status" -ne 0 ]
}
```

Run: `bats tests/quickshell.bats` — the new test FAILS (Audio.qml still says `pavucontrol`, InstallButton still says `gtk-launch`).

- [ ] **Step 2: Edit `bar/Audio.qml`**

Replace line 21:

```qml
        else Quickshell.execDetached(["pavucontrol"])
```

with:

```qml
        else Quickshell.execDetached(["pavucontrol-qt"])
```

- [ ] **Step 3: Edit `bar/InstallButton.qml`**

Replace line 23:

```qml
    onClicked: Quickshell.execDetached(["gtk-launch", "cyberos-install"])
```

with:

```qml
    // Same command as the .desktop Exec and the Super+I bind -- gtk-launch
    // left with GTK. List form: no shell, no quoting pitfalls.
    onClicked: Quickshell.execDetached(["foot", "--app-id=cyberos-installer", "--title=Install CyberOS", "sudo", "/usr/local/bin/cyberos-install"])
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `bats tests/quickshell.bats`
Expected: PASS (the `cyberos-install` grep in the install-button test still matches the new exec string).

- [ ] **Step 5: Commit**

```bash
git add profile/airootfs/etc/skel/.config/quickshell/bar tests/quickshell.bats
git commit -m "shell: pavucontrol-qt and direct installer exec; last gtk-launch gone"
```

---

### Task 7: Launcher categories + Security entries

**Files:**
- Modify: `profile/airootfs/etc/skel/.config/quickshell/launcher/Launcher.qml` (category row, `groupOf()`, filter, Tab cycling)
- Create: `profile/airootfs/usr/local/share/applications/metasploit.desktop`
- Modify: `tests/quickshell.bats` (new test)

**Interfaces:**
- Consumes: `DesktopEntry.categories` (list of strings, verified present in quickshell-core.qmltypes) on the entries `DesktopEntries.applications.values` already used by the launcher.
- Produces: category groups `["All","Security","Development","Internet","Office","Graphics","Media","System","Utilities"]`; a `groupOf(entry)` function; the `metasploit.desktop` id `metasploit.desktop` under `/usr/local/share/applications` (first in default `XDG_DATA_DIRS`, an unowned path so archiso is happy).

- [ ] **Step 1: Write the failing test**

Append to `tests/quickshell.bats` (note: `metasploit.desktop` lives outside `$QS`, so anchor on `BATS_TEST_DIRNAME`):

```bash
@test "launcher groups apps into categories with a Security group" {
  grep -q '"Security", "Development", "Internet"' "$QS/launcher/Launcher.qml"
  grep -q 'function groupOf' "$QS/launcher/Launcher.qml"
  grep -q 'activeGroup' "$QS/launcher/Launcher.qml"
  grep -q '"Wireshark": "Security"' "$QS/launcher/Launcher.qml"
  d="$BATS_TEST_DIRNAME/../profile/airootfs/usr/local/share/applications/metasploit.desktop"
  grep -q 'Categories=Security;' "$d"
  grep -q 'Exec=foot' "$d"
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bats tests/quickshell.bats`
Expected: the new test FAILS.

- [ ] **Step 3: Add category state + grouping to `Launcher.qml`**

Insert after the `columns` property (line 30):

```qml
    // Category chips. First match in priority order wins; anything unmatched
    // lands in Utilities. freedesktop "Security" is a registered additional
    // category -- our own .desktop entries (metasploit.desktop) set it, and
    // nameOverrides catches shipped tools whose upstream Categories don't
    // (wireshark says Network;Monitor).
    readonly property var groups: ["All", "Security", "Development", "Internet",
        "Office", "Graphics", "Media", "System", "Utilities"]
    property string activeGroup: "All"

    readonly property var nameOverrides: ({
        "Wireshark": "Security",
        "Ghidra": "Security"
    })

    function groupOf(entry) {
        const o = nameOverrides[entry.name];
        if (o !== undefined) return o;
        const c = entry.categories;
        const has = list => list.some(x => c.includes(x));
        if (has(["Security"])) return "Security";
        if (has(["Development", "IDE", "Debugger", "RevisionControl"])) return "Development";
        if (has(["Network", "WebBrowser", "Email", "P2P"])) return "Internet";
        if (has(["Office", "WordProcessor", "Spreadsheet", "Presentation"])) return "Office";
        if (has(["Graphics", "Photography"])) return "Graphics";
        if (has(["AudioVideo", "Audio", "Video", "Player"])) return "Media";
        if (has(["System", "Settings", "HardwareSettings", "Monitor",
                 "TerminalEmulator", "FileManager", "Emulator"])) return "System";
        return "Utilities";
    }
```

Then extend the `filtered` binding (line 36–41) — replace its `.filter(...)` line with:

```qml
            .filter(a => !a.noDisplay
                && (root.activeGroup === "All" || root.groupOf(a) === root.activeGroup)
                && (q === "" || a.name.toLowerCase().includes(q)))
```

- [ ] **Step 4: Add the chip row and Tab cycling**

In the `ColumnLayout` (after the `TextField`, before the `GridView`), insert:

```qml
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: root.groups
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        implicitWidth: chipLabel.implicitWidth + 14
                        implicitHeight: chipLabel.implicitHeight + 8
                        radius: height / 2
                        color: root.activeGroup === chip.modelData ? Cyber.Theme.sel : "transparent"
                        border.width: 1
                        border.color: root.activeGroup === chip.modelData ? Cyber.Theme.accent : Cyber.Theme.border

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: chip.modelData
                            color: root.activeGroup === chip.modelData ? Cyber.Theme.fg : Cyber.Theme.muted
                            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 3 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.activeGroup = chip.modelData
                        }
                    }
                }
            }
```

And in `filterField`'s `Keys.onPressed` switch, add two cases before `case Qt.Key_Return:`:

```qml
                    case Qt.Key_Tab: {
                        const i = root.groups.indexOf(root.activeGroup);
                        root.activeGroup = root.groups[(i + 1) % root.groups.length];
                        event.accepted = true;
                        break;
                    }
                    case Qt.Key_Backtab: {
                        const i = root.groups.indexOf(root.activeGroup);
                        root.activeGroup = root.groups[(i - 1 + root.groups.length) % root.groups.length];
                        event.accepted = true;
                        break;
                    }
```

If the chip row makes 420px feel cramped, bump `implicitHeight` (line 25) to `460` — judgement call at VM-verification time.

- [ ] **Step 5: Create `metasploit.desktop`**

Create `profile/airootfs/usr/local/share/applications/metasploit.desktop`:

```
[Desktop Entry]
Type=Application
Name=Metasploit Console
Comment=msfconsole — the Metasploit Framework interactive console
Exec=foot --title=Metasploit msfconsole
Icon=utilities-terminal
Terminal=false
Categories=Security;
Keywords=exploit;pentest;msf;metasploit;
```

- [ ] **Step 6: Syntax-check and run the tests**

Run: the Task 4 `qs check` invocation, then `bats tests/quickshell.bats`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add profile/airootfs/etc/skel/.config/quickshell/launcher profile/airootfs/usr/local/share/applications tests/quickshell.bats
git commit -m "shell: launcher category chips; Security group with metasploit entry"
```

---

### Task 8: cyberos-theme — drop gsettings, flip GTK3 ini + qt6ct palette

**Files:**
- Modify: `profile/airootfs/usr/local/bin/cyberos-theme:173-176` (the gsettings block)
- Modify: `tests/quickshell-theme.bats` (new test)

**Interfaces:**
- Consumes: the `$MODE` (`dark`/`light`) and `$CFG` (`~/.config`) variables already defined earlier in `cyberos-theme`; skel files `gtk-3.0/settings.ini` and `qt6ct/qt6ct.conf` (Task 2 kept both).
- Produces: nothing later tasks use.

- [ ] **Step 1: Write the failing test**

Append to `tests/quickshell-theme.bats`:

```bash
@test "theme toggle flips gtk3 prefer-dark + qt6ct palette; gsettings gone" {
  t="$BATS_TEST_DIRNAME/../profile/airootfs/usr/local/bin/cyberos-theme"
  run grep 'gsettings' "$t"
  [ "$status" -ne 0 ]
  grep -q 'gtk-application-prefer-dark-theme' "$t"
  grep -q 'qt6ct.conf' "$t"
  grep -q 'color_scheme_path' "$t"
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bats tests/quickshell-theme.bats`
Expected: the new test FAILS (gsettings still present); existing tests pass.

- [ ] **Step 3: Replace the gsettings block**

In `cyberos-theme`, replace:

```bash
gsettings set org.gnome.desktop.interface color-scheme \
  "$([[ $MODE == dark ]] && echo prefer-dark || echo prefer-light)" 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme \
  "$([[ $MODE == dark ]] && echo Adwaita-dark || echo Adwaita)" 2>/dev/null || true
```

with:

```bash
# gsettings left with the GNOME packages. Firefox (GTK3) reads settings.ini
# directly; Qt apps follow qt6ct's palette. Neither picks the change up until
# the app restarts -- same as the old gsettings path without a settings portal.
GTK3INI=$CFG/gtk-3.0/settings.ini
[[ -f $GTK3INI ]] && sed -i \
  "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=$([[ $MODE == dark ]] && echo 1 || echo 0)/" \
  "$GTK3INI"
QT6CT_SCHEME=/usr/share/qt6ct/colors/$([[ $MODE == dark ]] && echo darker || echo airy).conf
[[ -f $QT6CT_SCHEME && -f $CFG/qt6ct/qt6ct.conf ]] && sed -i \
  "s#^color_scheme_path=.*#color_scheme_path=$QT6CT_SCHEME#" "$CFG/qt6ct/qt6ct.conf"
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `bats tests/quickshell-theme.bats && bash -n profile/airootfs/usr/local/bin/cyberos-theme`
Expected: PASS, and `bash -n` silent.

- [ ] **Step 5: Commit**

```bash
git add profile/airootfs/usr/local/bin/cyberos-theme tests/quickshell-theme.bats
git commit -m "theme: flip gtk3 ini + qt6ct palette instead of gsettings"
```

---

### Task 9: Sweep, full test run, ISO build + VM verification, PR

**Files:**
- Modify: `CHANGELOG.md` (new entry)
- Possibly modify: any file the sweep greps turn up.

**Interfaces:**
- Consumes: everything above.
- Produces: the release-ready branch and PR.

- [ ] **Step 1: Repo-wide sweep for stragglers**

```bash
cd ~/Work/cyberos
grep -rn 'gtk-launch\|nm-applet\|blueman\|pavucontrol\b\|thunar\|zathura\|file-roller\|gnome-calculator\|gnome-text-editor\|gnome-disk\|nwg-look\|network-manager-applet\|xdg-desktop-portal-gtk' \
  --include='*' -l profile/ tests/ docs/ README.md | grep -v 'plans/'
```

Expected: no output (this plan file excluded). Fix any hit the earlier tasks missed, matching the replacement decisions above.

- [ ] **Step 2: Run the whole suite**

Run: `bats tests/`
Expected: ALL PASS.

- [ ] **Step 3: CHANGELOG entry**

Add at the top of `CHANGELOG.md`, matching its existing entry format:

```markdown
## Unreleased
- GTK/GNOME apps removed; Qt6/KDE suite in their place: dolphin (files), ark
  (archives), okular (PDF), gwenview (images), kate (editor), kcalc,
  partitionmanager, pavucontrol-qt. Portal FileChooser now served by
  xdg-desktop-portal-kde.
- nm-applet, nm-connection-editor and blueman replaced by native Quickshell
  panels: `qs ipc call wifi toggle` / `qs ipc call bt toggle`, wired to the
  bar's network and bluetooth chips.
- Launcher (Super+D) groups apps into category chips: Security, Development,
  Internet, Office, Graphics, Media, System, Utilities. Tab cycles groups.
  Metasploit gets a Security launcher entry; Wireshark/Ghidra are re-grouped
  into Security.
- cyberos-theme now flips GTK3 settings.ini and the qt6ct palette instead of
  gsettings; light mode reaches Qt apps for the first time.
```

- [ ] **Step 4: Commit and rebuild the ISO (user runs the build)**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog for the Qt6/quickshell migration"
```

Then ask the user to run:

```bash
cd ~/Work/cyberos && ./build.sh --skip-aur
# or directly: sudo rm -rf work/iso && sudo mkarchiso -v -w work/iso -o out profile 2>&1 | tee work/build.log
```

Watch `work/build.log` (Monitor tool). The likeliest failure mode is a "conflicting files" error from a new airootfs path — if it happens, the offending file is named in the log; move it to an unowned path per the Global Constraints.

- [ ] **Step 5: Live-boot verification in QEMU (`./test-vm.sh`)**

Drive via the monitor socket + `grim -o <output>` screenshots (see memory: sendkey has no `~`, screenshot by output name, confirm a focused terminal before typing). Checklist:

1. Bar renders; network chip click opens the Wi-Fi panel showing "Wired: connected" + "No Wi-Fi adapter"; Esc closes. `qs ipc call wifi toggle` also opens/closes it.
2. Bluetooth chip click opens the Bluetooth panel showing "No Bluetooth adapter"; Esc closes.
3. Super+D launcher: category chips render; "Security" shows Metasploit Console + Wireshark + Ghidra; "System" shows Dolphin/foot/VirtualBox; Tab cycles chips; search still filters.
4. Super+E opens Dolphin; open a PDF from Dolphin → Okular; open a PNG → Gwenview (mimeapps routing).
5. Audio chip click opens pavucontrol-qt (floats, per window rule). `hyprctl clients -j` shows its real class — if it is not `pavucontrol-qt`, fix the Task 3 float-rule regex to the observed class.
6. Install button and Super+I both open the foot installer window (class `cyberos-installer`, floating 920x640).
7. `pacman -Q gtk4 libadwaita blueman pavucontrol thunar 2>&1` in the guest → all "was not found". `pacman -Q gtk3` → present (firefox dependency, expected).
8. `journalctl --user -b | grep -iE 'qml|quickshell' | grep -icE 'error|warn'` → 0.
9. `cyberos-theme toggle` twice: wallpaper + bar flip; `grep prefer-dark ~/.config/gtk-3.0/settings.ini` flips 1→0→1; `grep color_scheme_path ~/.config/qt6ct/qt6ct.conf` flips darker→airy→darker.

Wi-Fi scanning/PSK-connect and Bluetooth pairing CANNOT be verified in QEMU — flag them for a bare-metal laptop boot before release, per the SPEC §6 manual pass.

- [ ] **Step 6: Push and open the PR**

```bash
git push -u origin desktop/qt6-apps
gh pr create --title "Qt6/Quickshell desktop: GTK apps out, categorised launcher" \
  --body "$(cat <<'EOF'
GTK/GNOME apps and applets are gone from the ISO. Dolphin/Ark/Okular/Gwenview/
Kate/KCalc/Partition Manager/pavucontrol-qt replace them; nm-applet and blueman
are replaced by native Quickshell Wi-Fi and Bluetooth panels; the launcher now
groups apps into category chips (Security first-class, with Metasploit/
Wireshark/Ghidra grouped there). SPEC §5.7 store client re-targeted to Qt6/QML.
Verified: full bats suite + live-boot checklist in QEMU (build log attached in
comments). Wi-Fi/BT interaction needs a bare-metal pass before release.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review (performed at write time)

- **Spec coverage:** the user's three asks map to: GTK removal → Tasks 1–3, 6, 8; Qt6+Quickshell replacements → Tasks 1, 4, 5, 6; categories → Task 7. SPEC.md's two GTK references (§5.7 client, §6.3 GUI-wizard sentence) are edited in Task 1. The §5.5 SigLevel gap and §5 store implementation are explicitly out of scope — nothing in this plan touches signing.
- **Type consistency:** IPC targets `wifi`/`bt` match between shell.qml handlers (Tasks 4/5) and chip exec calls; the installer exec string is byte-identical in Task 3 (bind + sed pattern) and Task 6 (InstallButton, list form of the same argv); `groupOf`/`activeGroup`/`groups` names are consistent across Task 7's steps; `pkg_listed` names in Task 1's two tests match its helper.
- **Placeholder scan:** all code blocks are complete; the two deliberately conditional steps (Task 3 Step 1 "if no such assertions exist", Task 9 Step 5 float-rule class check) state exactly what to do in each branch.
- **Known judgement points:** `pavucontrol-qt`'s Wayland app-id (verify in VM, Task 9.5), panel `margins.top: 44` versus actual bar height (visual check), launcher height 420→460 if chips crowd it (Task 7 Step 4 note).
