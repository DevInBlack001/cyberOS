# Quickshell-only Desktop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove every remaining KDE application from the CyberOS ISO and replace their roles with three native Quickshell QML surfaces — Files, Images, and a Pipewire Mixer.

**Architecture:** The three surfaces live inside the existing `qs` process beside the bar and panels, each behind a `LazyLoader` and opened by an `IpcHandler` — the pattern the Wi-Fi and Bluetooth panels already use. Files and Images are real toplevel `FloatingWindow`s (they tile and appear in the window switcher); the Mixer is a `PanelWindow` popup on the bar's speaker chip. `.desktop` entries exec back into the running shell (`qs ipc call files open %f`).

**Tech Stack:** archiso profile, Quickshell 0.3.1 (QML), Qt 6.11.2, `Qt.labs.folderlistmodel`, `Quickshell.Services.Pipewire`, Hyprland 0.56 Lua config, bats.

**Spec:** `docs/superpowers/specs/2026-09-01-quickshell-only-desktop-design.md` — read it alongside this plan; it carries the rationale (especially §2, why Firefox / VS Code / `xdg-desktop-portal-kde` survive).

## Global Constraints

Every API fact below was verified on this machine on 2026-09-01 by running it, not by reading docs. Trust these over intuition; three of them are counter-intuitive and two would cause real bugs if guessed.

- **Base branch:** this work builds on PR #16 (`desktop/qt6-apps`). Work on a new branch `desktop/quickshell-only`. `main` is branch-protected (PR + review); never push to it.
- **`PwNodeType` is a BITFLAG enum.** Verified numerics: `Audio=1, Video=2, Stream=4, Source=8, Sink=16`, so `AudioSink=17`, `AudioSource=9`, `AudioOutStream=21`, `AudioInStream=13`. **`AudioOutStream` (a playing application) carries the `Sink` bit**, so `node.isSink` is `true` for Firefox-playing-audio as well as for a real sound card. Classify with exact equality (`n.type === PwNodeType.AudioSink`), NEVER with `isSink`/`isStream`.
- **`FolderListModel` has no `fileURL` role** — `get(i, "fileURL")` returns `undefined`, and feeding that to `indexOf()` throws `TypeError: Passing incompatible arguments to C++ functions`. Working roles: `fileName`, `filePath`, `fileIsDir`, `fileSuffix`, `fileSize`, `fileModified`. **`indexOf()` requires a `"file://"`-prefixed string**: `m.indexOf("file://" + m.get(i, "filePath"))` returns the right index (verified); passing a bare path or `Qt.url(...)` returns `-1`.
- **`FloatingWindow` is exported from the `Quickshell` module** and creates a real toplevel window (verified at runtime). Properties: `title`, `minimumSize`, `maximumSize`, `minimized`, `maximized`, `fullscreen`, plus `color` and `implicitWidth`/`implicitHeight` from `ProxyWindowBase`.
- **`PwNode`**: `id, name, description, nickname, isSink, isStream, type, properties, audio, ready`. **`PwNodeAudio`**: `muted, volume, channels, volumes`. `Pipewire.nodes` (ObjectModel — use `.values`), `Pipewire.defaultAudioSink`, `Pipewire.defaultAudioSource`, `Pipewire.preferredDefaultAudioSink` (**writable** — this is how the Mixer switches device). Any node whose `audio` you read MUST be inside a `PwObjectTracker`, or its properties stay unbound.
- **`Process`**: `command`, `workingDirectory`, `environment`, `stdout`, `stderr`, `running`; methods `exec(argv)`, `startDetached()`, `signal()`, `write()`.
- **qmllint:** the suite uses `/usr/lib/qt6/bin/qmllint --bare`. Do NOT "improve" it to `-I /usr/lib/qt6/qml` — the stricter mode false-positives on Quickshell's interface types (`PanelWindow is not creatable`, `unknown grouped property scope margins`), all of which are correct at runtime. Verified both ways.
- **archiso copies `airootfs/` BEFORE pacstrap**, so no airootfs file may sit at a package-owned path. New `.desktop` files go under `/usr/local/share/applications/` (unowned, already in `XDG_DATA_DIRS`, proven by `metasploit.desktop`). Never `/usr/share/applications/`.
- **bats negated assertions** must be `run cmd; [ "$status" -ne 0 ]` — a bare `! cmd` is swallowed by bash errexit. `[[ "$output" != *x* ]]` string checks are fine.
- **QML files must contain no raw private-use glyphs** — `tests/quickshell.bats` enforces `\uXXXX` escapes only. PUA bytes are invisible in tool output.
- **Theme tokens** (from `Theme.qml`, use these names): `bg, surface, fg, muted, accent, accent2, alert, border, sel, mode, dark, barAlpha, fontFamily, fontSize, barHeight, radius`. Reach them as `Cyber.Theme.<token>` after `import ".." as Cyber` (or `import "../" as Cyber` from `apps/`).
- **Commit style** `area: message`; git author email is already `edbron411@gmail.com` — do not change git config.
- **`wl-copy` takes its text as argv** (`wl-copy -- <text>`), so clipboard actions need no shell.
- Claude cannot `sudo`. The ISO rebuild is user-run: `./build.sh --skip-aur 2>&1 | tee work/build.log`.

## File Structure

| File | Responsibility |
|---|---|
| `profile/airootfs/etc/skel/.config/quickshell/apps/Files.qml` | Files window: sidebar, breadcrumb, directory grid, context actions |
| `profile/airootfs/etc/skel/.config/quickshell/apps/Images.qml` | Image viewer window: display, zoom/pan, folder walk |
| `profile/airootfs/etc/skel/.config/quickshell/popups/Mixer.qml` | Pipewire mixer panel: outputs, app streams, input |
| `profile/airootfs/usr/local/share/applications/cyberos-files.desktop` | Launcher + `inode/directory` handler |
| `profile/airootfs/usr/local/share/applications/cyberos-images.desktop` | Launcher + image mime handler |
| `profile/airootfs/etc/skel/.config/quickshell/shell.qml` | Wires all three (LazyLoader + IpcHandler), as it already does for six surfaces |
| `tests/quickshell-apps.bats` | Tests for the three new surfaces |
| `tests/packages.bats` | Extended with the KDE removals and CLI additions |

---

### Task 1: Package strip and CLI tooling

**Files:**
- Modify: `profile/packages.x86_64`
- Modify: `tests/packages.bats`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: the ISO package set every later task assumes — `xdg-utils` (gives `xdg-open`, used by Files Task 4), `trash-cli` (gives `trash-put`, used by Files Task 4), and the absence of the KDE apps whose roles Tasks 2–4 replace. `7zip` and `unzip` were already present and stay.

- [ ] **Step 0: Create the branch**

```bash
cd ~/Work/cyberos
git checkout desktop/qt6-apps && git pull --ff-only 2>/dev/null || true
git checkout -b desktop/quickshell-only
```

- [ ] **Step 1: Write the failing test**

Append to `tests/packages.bats` (the file already defines `PKGS` and the `pkg_listed` helper — reuse them, do not redefine):

```bash
@test "KDE applications are gone from packages.x86_64" {
  for p in dolphin ark okular gwenview kate kcalc partitionmanager \
           pavucontrol-qt kio-extras kio-fuse ffmpegthumbs \
           kdegraphics-thumbnailers breeze-icons; do
    run pkg_listed "$p"
    [ "$status" -ne 0 ]
  done
}

@test "headless Qt services and CLI tooling the QML surfaces need are present" {
  # portal-kde is the FileChooser backend for firefox/code (no window, no
  # KDE app); udisks2 mounts removable media; both are daemons, not apps.
  for p in xdg-desktop-portal-kde udisks2 xdg-utils trash-cli 7zip unzip; do
    pkg_listed "$p"
  done
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bats tests/packages.bats`
Expected: both new tests FAIL (KDE apps still listed; `xdg-utils`/`trash-cli` absent).

- [ ] **Step 3: Edit `profile/packages.x86_64`**

1. In the `# ---- audio / bluetooth ----` section, delete `pavucontrol-qt` (the QML Mixer replaces it in Task 2).
2. Replace the whole `# ---- apps ----` section with:

```
# ---- apps ----
firefox
# Firefox is also the PDF viewer (pdf.js) -- okular is gone with the rest of
# the KDE apps. Files/Images/Mixer are Quickshell QML surfaces now, so the
# only GUI apps on the ISO are the two that no QML surface can replace.
mpv
# xdg-open: how the QML file manager hands a file to its registered handler.
# Shell scripts, no toolkit dependency. Nothing else on the ISO provides it
# (dolphin used KIO internally).
xdg-utils
# trash-put: the freedesktop trash spec. `gio trash` left with gvfs, and the
# file manager must never rm a student's work.
trash-cli
```

3. In `# ---- fonts / theme ----`, delete `breeze-icons` (it existed only as the KDE apps' icon fallback; Papirus remains the icon theme).

Leave untouched: `xdg-desktop-portal-kde`, `udisks2`, `adwaita-cursors`, `7zip`, `unzip`, `qt6-*`.

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `bats tests/packages.bats`
Expected: PASS (4 tests — the two from PR #16 plus the two new ones).

- [ ] **Step 5: Commit**

```bash
git add profile/packages.x86_64 tests/packages.bats
git commit -m "packages: KDE apps out; xdg-utils and trash-cli in for the QML surfaces"
```

---

### Task 2: Mixer panel

**Files:**
- Create: `profile/airootfs/etc/skel/.config/quickshell/popups/Mixer.qml`
- Create: `tests/quickshell-apps.bats`
- Modify: `profile/airootfs/etc/skel/.config/quickshell/shell.qml`
- Modify: `profile/airootfs/etc/skel/.config/quickshell/bar/Audio.qml` (the `onClicked` line only)

**Interfaces:**
- Consumes: Task 1's package set (`pavucontrol-qt` is gone, so the bar chip must not launch it).
- Produces: IPC target `mixer` with `toggle()`, consumed by `bar/Audio.qml` in this task. Establishes `tests/quickshell-apps.bats` with `ROOT`/`QS` variables that Tasks 3 and 4 append to.

- [ ] **Step 1: Write the failing test**

Create `tests/quickshell-apps.bats`:

```bash
#!/usr/bin/env bats
# The three QML surfaces that replaced the KDE apps.
ROOT="$BATS_TEST_DIRNAME/.."
QS="$ROOT/profile/airootfs/etc/skel/.config/quickshell"

@test "mixer: classifies pipewire nodes by exact type, never by isSink" {
  f="$QS/popups/Mixer.qml"
  [ -f "$f" ]
  grep -q 'PwNodeType.AudioSink' "$f"
  grep -q 'PwNodeType.AudioOutStream' "$f"
  grep -q 'PwObjectTracker' "$f"
  grep -q 'preferredDefaultAudioSink' "$f"
  # AudioOutStream carries the Sink bit, so an isSink filter would list a
  # playing app as an output device. Guard the trap, not just the feature.
  run grep -E '\.isSink|\.isStream' "$f"
  [ "$status" -ne 0 ]
}

@test "mixer: wired into the shell and owns the bar's audio chip" {
  grep -q 'target: "mixer"' "$QS/shell.qml"
  grep -q 'Popups.Mixer' "$QS/shell.qml"
  grep -q '"mixer", "toggle"' "$QS/bar/Audio.qml"
  run grep 'pavucontrol' "$QS/bar/Audio.qml"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bats tests/quickshell-apps.bats`
Expected: both tests FAIL (file missing).

- [ ] **Step 3: Create `popups/Mixer.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import ".." as Cyber

// Replaces pavucontrol-qt. Opened via `qs ipc call mixer toggle` (shell.qml's
// IpcHandler flips the owning LazyLoader's `active`), so -- like every other
// popup here -- it is built fresh on open and destroyed on close.
//
// PwNodeType is a BITFLAG enum. Verified numerics: Audio=1, Video=2, Stream=4,
// Source=8, Sink=16, so AudioSink=17, AudioSource=9, AudioOutStream=21,
// AudioInStream=13. AudioOutStream therefore CARRIES THE SINK BIT: a playing
// application reports isSink === true exactly like a real sound card does, so
// filtering on isSink would list Firefox among the output devices. Every
// classification below compares `type` exactly for that reason.
PanelWindow {
    id: root

    signal closeRequested()

    anchors { top: true; right: true }
    margins { top: 44; right: 8 }
    implicitWidth: 380
    implicitHeight: 480
    color: "transparent"
    focusable: true
    aboveWindows: true

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream)
    readonly property var source: Pipewire.defaultAudioSource

    // A node's `audio` properties stay unbound until something tracks it --
    // the same requirement bar/Audio.qml satisfies for the default sink.
    PwObjectTracker {
        objects: root.sinks.concat(root.streams).concat(root.source ? [root.source] : [])
    }

    // Applications set application.name; fall back through description to the
    // raw node name so a stream is never rendered as a blank row.
    function labelFor(node) {
        return (node.properties && node.properties["application.name"])
            || node.description || node.name || "Unknown";
    }

    // One row per volume-bearing node. Inline component so the three sections
    // below share it instead of repeating the slider/mute/label block.
    component VolumeRow: RowLayout {
        id: row
        required property var node
        required property string label
        Layout.fillWidth: true
        spacing: 6

        Text {
            Layout.preferredWidth: 96
            text: row.label
            color: Cyber.Theme.fg
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
            elide: Text.ElideRight
        }
        Slider {
            Layout.fillWidth: true
            from: 0; to: 1
            value: row.node?.audio.volume ?? 0
            onMoved: if (row.node) row.node.audio.volume = value
        }
        Text {
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round((row.node?.audio.volume ?? 0) * 100) + "%"
            color: Cyber.Theme.muted
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 3 }
        }
        // volume-xmark / volume-up -- same glyphs as bar/Audio.qml.
        Text {
            text: (row.node?.audio.muted ?? false) ? "\ueee8" : "\uf028"
            color: (row.node?.audio.muted ?? false) ? Cyber.Theme.alert : Cyber.Theme.fg
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
            MouseArea {
                anchors.fill: parent
                onClicked: if (row.node) row.node.audio.muted = !row.node.audio.muted
            }
        }
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
            spacing: 10

            Text {
                text: "Sound"
                color: Cyber.Theme.fg
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 2; bold: true }
            }

            // ---- output devices ----
            Text {
                text: "Output"
                color: Cyber.Theme.accent
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 2 }
            }
            Text {
                visible: root.sinks.length === 0
                text: "No output devices"
                color: Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
            }
            Repeater {
                model: root.sinks
                delegate: ColumnLayout {
                    id: sinkEntry
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 2

                    // The device-select click target is this name row ONLY,
                    // never the whole entry: a MouseArea covering the entry
                    // would sit over the volume slider below and eat its
                    // drag. The MouseArea is also parented to a plain Item,
                    // not to the RowLayout -- a MouseArea placed directly in
                    // a layout is laid out as a cell of it.
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 22

                        RowLayout {
                            anchors.fill: parent
                            spacing: 6
                            // dot-circle when selected, circle when not; both
                            // cmap-verified in JetBrainsMono Nerd Font.
                            Text {
                                text: Pipewire.defaultAudioSink === sinkEntry.modelData ? "\uf192" : "\uf111"
                                color: Pipewire.defaultAudioSink === sinkEntry.modelData
                                    ? Cyber.Theme.accent : Cyber.Theme.muted
                                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 2 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.labelFor(sinkEntry.modelData)
                                color: Cyber.Theme.fg
                                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Pipewire.preferredDefaultAudioSink = sinkEntry.modelData
                        }
                    }
                    VolumeRow { node: sinkEntry.modelData; label: "" }
                }
            }

            // ---- application streams ----
            Text {
                text: "Applications"
                color: Cyber.Theme.accent
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 2 }
            }
            Text {
                visible: root.streams.length === 0
                text: "Nothing is playing"
                color: Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
            }
            Repeater {
                model: root.streams
                delegate: VolumeRow {
                    required property var modelData
                    node: modelData
                    label: root.labelFor(modelData)
                }
            }

            // ---- input ----
            Text {
                text: "Input"
                color: Cyber.Theme.accent
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 2 }
            }
            VolumeRow {
                visible: root.source !== null
                node: root.source
                label: root.source ? root.labelFor(root.source) : ""
            }
            Text {
                visible: root.source === null
                text: "No input device"
                color: Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
            }

            Item { Layout.fillHeight: true }

            Text {
                text: "Click a device to make it default · Esc to close"
                color: Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 3 }
            }
        }
    }
}
```

- [ ] **Step 4: Wire it into `shell.qml`**

After the `bt` LazyLoader, add:

```qml
    LazyLoader {
        id: mixer
        Popups.Mixer { onCloseRequested: mixer.active = false }
    }
```

After the `bt` IpcHandler, add:

```qml
    // `qs ipc call mixer toggle` -- replaces pavucontrol-qt.
    IpcHandler {
        target: "mixer"
        function toggle(): void {
            mixer.activeAsync ? mixer.active = false : mixer.activeAsync = true
        }
    }
```

- [ ] **Step 5: Retarget the bar chip**

In `bar/Audio.qml`, replace the `pavucontrol-qt` exec line:

```qml
        else Quickshell.execDetached(["pavucontrol-qt"])
```

with:

```qml
        else Quickshell.execDetached(["qs", "ipc", "call", "mixer", "toggle"])
```

Change nothing else in that file — it carries `\uXXXX` glyph escapes.

- [ ] **Step 6: Lint and test**

Run: `/usr/lib/qt6/bin/qmllint --bare profile/airootfs/etc/skel/.config/quickshell/popups/Mixer.qml && bats tests/quickshell-apps.bats tests/quickshell.bats`
Expected: qmllint silent; all bats PASS.

- [ ] **Step 7: Commit**

```bash
git add profile/airootfs/etc/skel/.config/quickshell tests/quickshell-apps.bats
git commit -m "shell: QML pipewire mixer replaces pavucontrol-qt"
```

---

### Task 3: Images viewer

**Files:**
- Create: `profile/airootfs/etc/skel/.config/quickshell/apps/Images.qml`
- Create: `profile/airootfs/usr/local/share/applications/cyberos-images.desktop`
- Modify: `profile/airootfs/etc/skel/.config/quickshell/shell.qml`
- Modify: `tests/quickshell-apps.bats`

**Interfaces:**
- Consumes: the `LazyLoader`/`IpcHandler` pattern from Task 2.
- Produces: IPC target `images` with `open(path: string)`, and the desktop id **`cyberos-images.desktop`**, both consumed by Task 5's `mimeapps.list` and by Task 4's Files (which opens images through `xdg-open`, which resolves to this entry).

- [ ] **Step 1: Write the failing test**

Append to `tests/quickshell-apps.bats`:

```bash
@test "images: FloatingWindow, folder walk without the absent fileURL role" {
  f="$QS/apps/Images.qml"
  [ -f "$f" ]
  grep -q 'FloatingWindow' "$f"
  grep -q 'Qt.labs.folderlistmodel' "$f"
  # indexOf() needs a file:// prefixed string; the fileURL role does not
  # exist and returns undefined, which makes indexOf throw.
  grep -q 'indexOf("file://"' "$f"
  run grep 'fileURL' "$f"
  [ "$status" -ne 0 ]
}

@test "images: ipc open target and desktop entry at an unowned path" {
  grep -q 'target: "images"' "$QS/shell.qml"
  grep -q 'function open' "$QS/shell.qml"
  d="$ROOT/profile/airootfs/usr/local/share/applications/cyberos-images.desktop"
  [ -f "$d" ]
  grep -q 'Exec=qs ipc call images open %f' "$d"
  grep -q 'MimeType=image/' "$d"
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bats tests/quickshell-apps.bats`
Expected: the two new tests FAIL; Task 2's still pass.

- [ ] **Step 3: Create `apps/Images.qml`**

```qml
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import "../" as Cyber

// Replaces gwenview. A real toplevel window (FloatingWindow), not a layer
// surface, so it tiles and shows up in the window switcher like an app.
// Opened by `qs ipc call images open <path>` -- which is exactly what
// cyberos-images.desktop execs, so mime-opening a picture from anywhere
// (Files, Firefox downloads) lands here.
//
// Arrow keys walk the containing directory. FolderListModel exposes NO
// fileURL role (it returns undefined, and indexOf() then throws a TypeError
// about incompatible C++ arguments) -- so the current image's position comes
// from indexOf() fed a "file://"-prefixed filePath, which is verified to
// return the correct index.
FloatingWindow {
    id: root

    property string path: ""
    readonly property string fileName: root.path.split("/").pop()
    readonly property string dirPath: root.path.substring(0, root.path.lastIndexOf("/"))

    title: root.path === "" ? "Images"
        : root.fileName + "  —  " + img.sourceSize.width + "×" + img.sourceSize.height
    implicitWidth: 900
    implicitHeight: 620
    minimumSize: Qt.size(360, 240)
    color: Cyber.Theme.bg

    FolderListModel {
        id: dir
        folder: root.dirPath === "" ? "" : "file://" + root.dirPath
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.bmp", "*.svg"]
    }

    // Step by +1/-1 through the filtered listing, wrapping at both ends so a
    // student never hits a dead arrow key.
    function step(delta) {
        if (dir.count === 0) return;
        const here = dir.indexOf("file://" + root.path);
        // -1 means the current file did not match nameFilters; start at 0.
        const next = here < 0 ? 0 : (here + delta + dir.count) % dir.count;
        root.path = dir.get(next, "filePath");
    }

    function fit()  { img.scale = 1; img.x = 0; img.y = 0; }
    function zoom(factor) { img.scale = Math.max(0.1, Math.min(8, img.scale * factor)); }

    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Right:  root.step(1);  event.accepted = true; break;
            case Qt.Key_Left:   root.step(-1); event.accepted = true; break;
            case Qt.Key_Plus:
            case Qt.Key_Equal:  root.zoom(1.25); event.accepted = true; break;
            case Qt.Key_Minus:  root.zoom(0.8);  event.accepted = true; break;
            case Qt.Key_0:      root.fit(); event.accepted = true; break;
            case Qt.Key_1:      img.scale = 1; event.accepted = true; break;
            case Qt.Key_Escape: root.visible = false; event.accepted = true; break;
            }
        }

        Image {
            id: img
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            source: root.path === "" ? "" : "file://" + root.path
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            // Big photos on a software-rendered VM: cap the decode, keep the
            // smooth filter for the common downscale.
            sourceSize.width: 4096
            smooth: true

            // Drag to pan once zoomed past fit; MouseArea also owns the
            // scroll-to-zoom so the two never fight over the same event.
            MouseArea {
                anchors.fill: parent
                drag.target: img
                acceptedButtons: Qt.LeftButton
                onWheel: wheel => root.zoom(wheel.angleDelta.y > 0 ? 1.15 : 0.87)
                onDoubleClicked: root.fit()
            }
        }

        Text {
            visible: root.path === "" || img.status === Image.Error
            anchors.centerIn: parent
            text: root.path === "" ? "No image" : "Could not load\n" + root.fileName
            horizontalAlignment: Text.AlignHCenter
            color: Cyber.Theme.muted
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
        }

        Rectangle {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 10 }
            width: hint.implicitWidth + 16
            height: hint.implicitHeight + 8
            radius: Cyber.Theme.radius / 2
            color: Cyber.Theme.surface
            opacity: 0.85
            Text {
                id: hint
                anchors.centerIn: parent
                text: "← → browse · +/- zoom · 0 fit · Esc close"
                color: Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 3 }
            }
        }
    }
}
```

- [ ] **Step 4: Wire it into `shell.qml`**

Add the import beside the existing ones at the top:

```qml
import "apps" as Apps
```

After the `mixer` LazyLoader, add (note `active: false` plus an explicit id — the window persists across opens so a second `open` call just retargets it):

```qml
    LazyLoader {
        id: images
        Apps.Images {}
    }
```

After the `mixer` IpcHandler, add:

```qml
    // `qs ipc call images open <path>` -- cyberos-images.desktop execs this,
    // so every mime-opened picture arrives here. Reuses one window: a second
    // open retargets the existing viewer rather than stacking windows.
    // `active`, NOT `activeAsync`: async loading returns before the component
    // exists, so `item` would still be null on the first open and the path
    // would never be applied. The toggle popups can use activeAsync because
    // they carry no argument; an open-with-path handler cannot.
    IpcHandler {
        target: "images"
        function open(path: string): void {
            images.active = true;
            if (images.item) {
                images.item.path = path;
                images.item.visible = true;
            }
        }
    }
```

- [ ] **Step 5: Create the desktop entry**

Create `profile/airootfs/usr/local/share/applications/cyberos-images.desktop`:

```
[Desktop Entry]
Type=Application
Name=Images
Comment=View pictures
Exec=qs ipc call images open %f
Icon=image-x-generic
Terminal=false
Categories=Graphics;Viewer;
MimeType=image/png;image/jpeg;image/gif;image/webp;image/bmp;image/svg+xml;
Keywords=image;picture;photo;viewer;
```

- [ ] **Step 6: Lint and test**

Run: `/usr/lib/qt6/bin/qmllint --bare profile/airootfs/etc/skel/.config/quickshell/apps/Images.qml && bats tests/quickshell-apps.bats tests/quickshell.bats`
Expected: qmllint silent; all PASS.

- [ ] **Step 7: Commit**

```bash
git add profile/airootfs/etc/skel/.config/quickshell profile/airootfs/usr/local/share/applications tests/quickshell-apps.bats
git commit -m "shell: QML image viewer replaces gwenview"
```

---

### Task 4: Files manager

**Files:**
- Create: `profile/airootfs/etc/skel/.config/quickshell/apps/Files.qml`
- Create: `profile/airootfs/usr/local/share/applications/cyberos-files.desktop`
- Modify: `profile/airootfs/etc/skel/.config/quickshell/shell.qml`
- Modify: `profile/airootfs/etc/skel/.config/hypr/hyprland.lua` (the `files` program line)
- Modify: `tests/quickshell-apps.bats`, `tests/hyprland-lua.bats`

**Interfaces:**
- Consumes: `xdg-utils` and `trash-cli` from Task 1; the `LazyLoader`/`IpcHandler` pattern from Tasks 2–3.
- Produces: IPC target `files` with `open(path: string)`; desktop id **`cyberos-files.desktop`**, consumed by Task 5's `mimeapps.list` for `inode/directory`.

- [ ] **Step 1: Write the failing test**

Append to `tests/quickshell-apps.bats`:

```bash
@test "files: FloatingWindow over FolderListModel with the verified roles" {
  f="$QS/apps/Files.qml"
  [ -f "$f" ]
  grep -q 'FloatingWindow' "$f"
  grep -q 'Qt.labs.folderlistmodel' "$f"
  grep -q 'showDirsFirst' "$f"
  run grep 'fileURL' "$f"
  [ "$status" -ne 0 ]
}

@test "files: opens via xdg-open, deletes via trash-put, never rm" {
  f="$QS/apps/Files.qml"
  grep -q '"xdg-open"' "$f"
  grep -q '"trash-put"' "$f"
  grep -q '"7z", "x"' "$f"
  # A file manager that shells out to rm is a data-loss bug, not a feature.
  run grep -E '"rm"|rm -' "$f"
  [ "$status" -ne 0 ]
}

@test "files: ipc target, desktop entry, and Super+E open it" {
  grep -q 'target: "files"' "$QS/shell.qml"
  d="$ROOT/profile/airootfs/usr/local/share/applications/cyberos-files.desktop"
  [ -f "$d" ]
  grep -q 'Exec=qs ipc call files open %f' "$d"
  grep -q 'MimeType=inode/directory' "$d"
}
```

Then in `tests/hyprland-lua.bats`, update the Super+E assertion added in PR #16 — it currently expects `dolphin`:

```bash
  [[ "$output" == *"bindcmd SUPER + E :: qs ipc call files open"* ]]
```

- [ ] **Step 2: Run to make sure they fail**

Run: `bats tests/quickshell-apps.bats tests/hyprland-lua.bats`
Expected: the three new tests FAIL, and the Super+E assertion FAILS (still `dolphin`).

- [ ] **Step 3: Create `apps/Files.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../" as Cyber

// Replaces dolphin. A real toplevel window (FloatingWindow), opened by
// Super+E and by `qs ipc call files open <path>`.
//
// v1 is deliberately browse-and-open: navigate, open with the registered
// handler, extract an archive, trash a file, open a terminal here, copy a
// path. Rename/copy/cut/paste and multi-select are NOT here -- a solid
// browser beats a half-built file-operations engine, and every destructive
// path goes through trash-put rather than rm.
//
// FolderListModel role names are load-bearing: fileName, filePath, fileIsDir
// and fileSuffix all resolve; fileURL does NOT (it returns undefined).
FloatingWindow {
    id: root

    property string path: Quickshell.env("HOME") || "/"

    title: "Files  —  " + root.path
    implicitWidth: 1000
    implicitHeight: 640
    minimumSize: Qt.size(560, 360)
    color: Cyber.Theme.bg

    readonly property var places: [
        { name: "Home",      dir: Quickshell.env("HOME") || "/" },
        { name: "Desktop",   dir: (Quickshell.env("HOME") || "") + "/Desktop" },
        { name: "Documents", dir: (Quickshell.env("HOME") || "") + "/Documents" },
        { name: "Downloads", dir: (Quickshell.env("HOME") || "") + "/Downloads" },
        { name: "Pictures",  dir: (Quickshell.env("HOME") || "") + "/Pictures" },
        { name: "Projects",  dir: (Quickshell.env("HOME") || "") + "/Projects" }
    ]

    readonly property var archiveSuffixes: ["zip", "7z", "gz", "bz2", "xz", "tar", "rar", "tgz"]

    function enter(dirPath) { root.path = dirPath; }

    function goUp() {
        const p = dir.parentFolder.toString().replace("file://", "");
        if (p !== "") root.path = p;
    }

    // Everything below is argv, never a shell string -- a filename with a
    // space or a quote in it is just one argument, not an injection.
    function openEntry(filePath, isDir) {
        if (isDir) root.enter(filePath);
        else Quickshell.execDetached(["xdg-open", filePath]);
    }
    function trashEntry(filePath) { Quickshell.execDetached(["trash-put", "--", filePath]); }
    function copyPath(filePath)   { Quickshell.execDetached(["wl-copy", "--", filePath]); }
    function terminalHere()       { Quickshell.execDetached(["foot", "-D", root.path]); }

    // 7z handles zip/7z/tar/gz/xz/rar alike; workingDirectory puts the output
    // beside the archive rather than wherever the shell happens to have been.
    Process { id: extractProc }
    function extract(filePath) {
        extractProc.workingDirectory = root.path;
        extractProc.exec(["7z", "x", "-y", filePath]);
    }

    FolderListModel {
        id: dir
        folder: "file://" + root.path
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------- sidebar ----------------
        Rectangle {
            Layout.preferredWidth: 180
            Layout.fillHeight: true
            color: Cyber.Theme.surface

            ColumnLayout {
                anchors { fill: parent; margins: 8 }
                spacing: 2

                Text {
                    text: "Places"
                    color: Cyber.Theme.muted
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 3 }
                }
                Repeater {
                    model: root.places
                    delegate: Rectangle {
                        id: place
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Cyber.Theme.radius / 2
                        color: root.path === place.modelData.dir ? Cyber.Theme.sel
                            : placeMouse.containsMouse ? Cyber.Theme.bg : "transparent"

                        Text {
                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            text: place.modelData.name
                            color: Cyber.Theme.fg
                            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
                        }
                        MouseArea {
                            id: placeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.enter(place.modelData.dir)
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // ---------------- main pane ----------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // breadcrumb
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                color: Cyber.Theme.bg

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 6

                    Text {
                        text: "\uf062"   // arrow-up
                        color: Cyber.Theme.fg
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                        MouseArea { anchors.fill: parent; onClicked: root.goUp() }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.path
                        color: Cyber.Theme.muted
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
                        elide: Text.ElideMiddle
                    }
                    Text {
                        text: "\uf120"   // terminal
                        color: Cyber.Theme.fg
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                        MouseArea { anchors.fill: parent; onClicked: root.terminalHere() }
                    }
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 128
                cellHeight: 104
                model: dir

                // Backspace goes up a level; the view holds focus so this
                // works without a dedicated key-catcher item.
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Backspace) { root.goUp(); event.accepted = true; }
                    else if (event.key === Qt.Key_Escape) { root.visible = false; event.accepted = true; }
                }

                delegate: Item {
                    id: cell
                    required property string fileName
                    required property string filePath
                    required property bool fileIsDir
                    required property string fileSuffix
                    width: grid.cellWidth
                    height: grid.cellHeight

                    readonly property bool isArchive:
                        !cell.fileIsDir && root.archiveSuffixes.indexOf(cell.fileSuffix.toLowerCase()) >= 0

                    Rectangle {
                        anchors { fill: parent; margins: 4 }
                        radius: Cyber.Theme.radius / 2
                        color: cellMouse.containsMouse ? Cyber.Theme.sel : "transparent"

                        ColumnLayout {
                            anchors { fill: parent; margins: 6 }
                            spacing: 4

                            IconImage {
                                Layout.alignment: Qt.AlignHCenter
                                implicitSize: 44
                                source: Quickshell.iconPath(
                                    cell.fileIsDir ? "folder" : "text-x-generic",
                                    "application-x-executable")
                            }
                            Text {
                                Layout.fillWidth: true
                                text: cell.fileName
                                color: Cyber.Theme.fg
                                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 3 }
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                            }
                        }

                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onDoubleClicked: root.openEntry(cell.filePath, cell.fileIsDir)
                            onClicked: mouse => { if (mouse.button === Qt.RightButton) ctx.popup(); }
                        }

                        Menu {
                            id: ctx
                            MenuItem {
                                text: cell.fileIsDir ? "Open folder" : "Open"
                                onTriggered: root.openEntry(cell.filePath, cell.fileIsDir)
                            }
                            MenuItem {
                                text: "Extract here"
                                enabled: cell.isArchive
                                onTriggered: root.extract(cell.filePath)
                            }
                            MenuItem { text: "Copy path"; onTriggered: root.copyPath(cell.filePath) }
                            MenuItem { text: "Move to Trash"; onTriggered: root.trashEntry(cell.filePath) }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 24
                color: Cyber.Theme.surface
                Text {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: dir.count + (dir.count === 1 ? " item" : " items")
                        + "  ·  double-click to open · right-click for actions · Backspace up"
                    color: Cyber.Theme.muted
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 3 }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Wire it into `shell.qml`**

After the `images` LazyLoader, add:

```qml
    LazyLoader {
        id: files
        Apps.Files {}
    }
```

After the `images` IpcHandler, add:

```qml
    // `qs ipc call files open <path>` -- Super+E and cyberos-files.desktop
    // both land here. An empty path means "open at $HOME", which is the
    // component's own default, so it is left alone in that case.
    // `active`, not `activeAsync` -- see the images handler above: the item
    // must exist by the time we assign to it.
    IpcHandler {
        target: "files"
        function open(path: string): void {
            files.active = true;
            if (files.item) {
                if (path !== "") files.item.path = path;
                files.item.visible = true;
            }
        }
    }
```

- [ ] **Step 5: Create the desktop entry**

Create `profile/airootfs/usr/local/share/applications/cyberos-files.desktop`:

```
[Desktop Entry]
Type=Application
Name=Files
Comment=Browse your files
Exec=qs ipc call files open %f
Icon=system-file-manager
Terminal=false
Categories=System;FileManager;
MimeType=inode/directory;
Keywords=files;folder;browser;manager;
```

- [ ] **Step 6: Point Super+E at it**

In `profile/airootfs/etc/skel/.config/hypr/hyprland.lua`, replace:

```lua
local files    = "dolphin"
```

with:

```lua
-- dolphin is gone; Files is a Quickshell surface in the running shell.
local files    = "qs ipc call files open ''"
```

- [ ] **Step 7: Lint and test**

Run: `/usr/lib/qt6/bin/qmllint --bare profile/airootfs/etc/skel/.config/quickshell/apps/Files.qml && bats tests/quickshell-apps.bats tests/quickshell.bats tests/hyprland-lua.bats`
Expected: qmllint silent; all PASS.

- [ ] **Step 8: Commit**

```bash
git add profile/airootfs/etc/skel/.config/quickshell profile/airootfs/usr/local/share/applications \
        profile/airootfs/etc/skel/.config/hypr/hyprland.lua tests/
git commit -m "shell: QML file manager replaces dolphin"
```

---

### Task 5: Rewiring, sweep, and release prep

**Files:**
- Modify: `profile/airootfs/etc/skel/.config/mimeapps.list`
- Modify: `profile/airootfs/etc/skel/.config/hypr/hyprland.lua` (float-utilities rule)
- Modify: `CHANGELOG.md`
- Modify: `tests/qt-desktop.bats`

**Interfaces:**
- Consumes: the desktop ids `cyberos-files.desktop` (Task 4) and `cyberos-images.desktop` (Task 3); the package set from Task 1.
- Produces: the release-ready branch.

- [ ] **Step 1: Update the failing test**

In `tests/qt-desktop.bats`, the mimeapps test from PR #16 asserts KDE desktop ids. Replace that whole test with:

```bash
@test "mimeapps.list routes to the QML surfaces and the two kept apps" {
  f="$AIROOTFS/etc/skel/.config/mimeapps.list"
  grep -qx 'inode/directory=cyberos-files.desktop' "$f"
  grep -qx 'image/png=cyberos-images.desktop' "$f"
  grep -qx 'application/pdf=firefox.desktop' "$f"
  grep -qx 'text/plain=code.desktop' "$f"
  grep -qx 'x-scheme-handler/https=firefox.desktop' "$f"
  # No KDE app ids may survive here -- those packages are gone, and a
  # dangling default silently breaks "Open with".
  run grep -E 'org\.kde\.|okularApplication' "$f"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bats tests/qt-desktop.bats`
Expected: that test FAILS (file still names KDE ids).

- [ ] **Step 3: Rewrite `mimeapps.list`**

Replace the whole file with:

```
[Default Applications]
inode/directory=cyberos-files.desktop
image/png=cyberos-images.desktop
image/jpeg=cyberos-images.desktop
image/gif=cyberos-images.desktop
image/webp=cyberos-images.desktop
image/bmp=cyberos-images.desktop
image/svg+xml=cyberos-images.desktop
application/pdf=firefox.desktop
text/html=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop
text/plain=code.desktop
text/x-python=code.desktop
text/markdown=code.desktop
application/json=code.desktop
video/mp4=mpv.desktop
video/x-matroska=mpv.desktop
video/webm=mpv.desktop
audio/mpeg=mpv.desktop
audio/flac=mpv.desktop
```

Archives get no default: extraction is the Files context action, and a
double-click on a `.zip` falling through to "no handler" is better than
opening a text editor on a binary.

- [ ] **Step 4: Drop the dead window rule**

In `hyprland.lua`, the float-utilities rule from PR #16 matches two apps that no longer exist. Replace:

```lua
hl.window_rule({ name = "float-utilities",
  match = { class = "^(pavucontrol-qt|org.kde.kcalc)$" },
  float = true })
```

with nothing — delete the rule entirely. Files and Images are tiled application windows by design, and the Mixer is a layer-shell panel that window rules do not apply to.

- [ ] **Step 5: Run the full suite**

Run: `bats tests/`
Expected: ALL PASS.

- [ ] **Step 6: Sweep for stragglers**

```bash
grep -rn 'dolphin\|gwenview\|okular\|\bkate\b\|kcalc\|pavucontrol\|partitionmanager\|breeze-icons\|\bark\b' \
  profile/ docs/SPEC.md README.md | grep -v 'plans/\|specs/'
```

Judge each hit: a comment explaining what replaced the tool is fine; a functional reference (an exec, a bind, a package name, a mimeapps id) is a straggler to fix. Record the classification of every hit in your report.

- [ ] **Step 7: CHANGELOG entry**

Add to the existing `### Changed` section under `## [Unreleased]` in `CHANGELOG.md` (do not create a second `### Changed` — there is one already):

```markdown
- The desktop is Quickshell-only: dolphin, gwenview, okular, kate, kcalc, ark,
  partitionmanager and pavucontrol-qt are gone, replaced by three native QML
  surfaces — Files (Super+E), Images, and a Pipewire Mixer on the bar's audio
  chip. Firefox (which is also the PDF viewer) and VS Code stay; so does the
  headless xdg-desktop-portal-kde, purely as the file-dialog backend.
- Added xdg-utils and trash-cli: the QML file manager opens files through
  xdg-open and deletes through trash-put, never rm.
```

- [ ] **Step 8: Commit**

```bash
git add profile/airootfs/etc/skel/.config/mimeapps.list \
        profile/airootfs/etc/skel/.config/hypr/hyprland.lua CHANGELOG.md tests/
git commit -m "desktop: route defaults to the QML surfaces; drop dead window rule"
```

- [ ] **Step 9: Hand the ISO build to the user**

Ask the user to run (Claude cannot sudo):

```bash
cd ~/Work/cyberos && ./build.sh --skip-aur 2>&1 | tee work/build.log
```

Watch `work/build.log`. The branch-specific risk is a "conflicting files" error if any new airootfs path turns out to be package-owned — both new `.desktop` files are under `/usr/local/share/applications/`, which is unowned, so this should not fire.

- [ ] **Step 10: QEMU live-boot verification**

`rm -f work/OVMF_VARS.4m.fd work/test-disk.qcow2` first (stale NVRAM beats `-boot d`), then `./test-vm.sh`. Drive it with `sendkey` over `work/qemu-mon.sock` and screenshot with `grim -o <output>`; confirm a terminal is focused before typing, and re-check the active workspace after every capture.

1. `pacman -Q dolphin gwenview okular kate kcalc ark partitionmanager pavucontrol-qt breeze-icons` → every one "was not found". `pacman -Q xdg-utils trash-cli xdg-desktop-portal-kde firefox` → all present.
2. **Mixer:** click the bar's speaker chip → panel opens showing the dummy sink under Output and "Nothing is playing" under Applications; move the slider and confirm `pamixer --get-volume` in the guest reports the new value; Esc closes.
3. **Mixer with a stream:** `mpv --no-video /usr/share/sounds/... &` (any audio file present), reopen → the app appears as its own row with its own slider.
4. **Files:** Super+E opens the window; sidebar navigates to Documents; Backspace goes up; double-click a folder enters it; the item count in the status bar matches `ls -1 | wc -l`.
5. **Files actions:** right-click a file → Copy path, then `wl-paste` shows it; create `test.zip` (`zip test.zip somefile`) and use Extract here → the extracted file appears; Move to Trash on a scratch file → it lands in `~/.local/share/Trash/files/`.
6. **Images:** double-click a PNG in Files → the viewer opens with correct dimensions in the title; Right arrow moves to the next image in that folder; `+`/`-` zoom; Esc closes.
7. `xdg-mime query default inode/directory` → `cyberos-files.desktop`; `image/png` → `cyberos-images.desktop`; `application/pdf` → `firefox.desktop`.
8. Launcher (Super+D): the "System" chip lists Files, "Graphics" lists Images.
9. `sudo journalctl -b | grep -iE 'qml|quickshell' | grep -icE 'error|warn'` → `0`.
10. `cyberos-theme toggle` twice → the three new surfaces re-theme live along with the bar (they read `Cyber.Theme`, which watches `theme.json`).

- [ ] **Step 11: Push and open the PR**

```bash
git push -u origin desktop/quickshell-only
gh pr create --title "Quickshell-only desktop: Files, Images and Mixer replace the KDE apps" \
  --body "$(cat <<'EOF'
Every GUI application on the ISO is now a Quickshell QML surface, except the
two nothing can replace: Firefox (also the PDF viewer) and VS Code.

- Files (Super+E) replaces dolphin: browse, open via xdg-open, extract via 7z,
  trash via trash-put, terminal-here, copy-path.
- Images replaces gwenview: zoom/pan, arrow-key folder walk.
- Mixer replaces pavucontrol-qt: per-device and per-application volume on the
  bar's audio chip, built on Quickshell's Pipewire service.

Also gone: okular, kate, kcalc, ark, partitionmanager, breeze-icons and the
kio/thumbnailer chain. xdg-desktop-portal-kde stays as the headless file-dialog
backend for Firefox/VS Code.

Verified: full bats suite plus a QEMU live-boot pass over all three surfaces.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review (performed at write time)

- **Spec coverage:** §3 removals → Task 1. §4 role table → Tasks 2–4 (calculator/PDF/editor/partitioning need no code, as the spec says). §5.1 IPC-in-one-process → the LazyLoader+IpcHandler wiring in Tasks 2–4. §5.2 window types → `FloatingWindow` in Tasks 3–4, `PanelWindow` in Task 2. §5.4 tooling gaps → Task 1. §6.1/6.2/6.3 → Tasks 4/3/2. §7 rewiring → Task 5 (the Super+E bind moved into Task 4, where the IPC target it calls is created — a reviewer could not approve Task 4 with a bind pointing at a nonexistent target). §8 testing → each task's test step plus Task 5 Step 10. §9 sequencing → task order.
- **Type consistency:** IPC targets `mixer`/`images`/`files` match between `shell.qml` handlers, the bar chip, the `.desktop` Exec lines, and the Hyprland bind. Desktop ids `cyberos-files.desktop`/`cyberos-images.desktop` match between Tasks 3/4 and Task 5's mimeapps. `Cyber.Theme` token names match `Theme.qml`. FolderListModel roles are confined to the verified set.
- **Spec correction made:** §6.1 originally said the sidebar reads `~/.config/user-dirs.dirs`; that file does not exist in the live session (`xdg-user-dirs-update` runs only at firstboot on an installed system, while `customize_airootfs.sh:13` creates the five directories for the live user). The spec is now corrected to a fixed list, and Task 4 implements the fixed list.
- **Known judgement points, all resolved in-plan rather than left open:** archives get no mimeapps default (Task 5 Step 3 says why); `Esc` in Files/Images hides the window rather than destroying the loader, because both are persistent single-window apps unlike the toggle popups; the float-utilities rule is deleted rather than retargeted.
- **Three defects found and fixed during this self-review, each of which would have shipped a bug:** (1) the Mixer and Files code carried *raw* PUA glyphs, which `tests/quickshell.bats` rejects outright — all are now `\uXXXX` escapes, and all seven codepoints were cmap-verified against the shipped `JetBrainsMonoNerdFont-Regular.ttf`; (2) the sink delegate reached its data through a `parent.parent.modelData` chain and placed a `MouseArea` directly inside a `RowLayout` (where it is laid out as a cell, and where it would have covered the volume slider) — it now uses a delegate `id` and confines the click target to the name row; (3) both `open(path)` IPC handlers used `activeAsync`, which returns before the component exists, so `item` would have been null and the path silently dropped on first open — both now use `active`.
