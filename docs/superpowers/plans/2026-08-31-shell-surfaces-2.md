# Shell Surfaces Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Execution starts only after the `installer/quickshell` plan completes and merges** — both pipelines share the checkout.

**Goal:** Convert notifications (mako) and rofi's four remaining roles (window switcher, emoji, calculator, clipboard) into the Quickshell shell, removing mako, rofi, rofi-emoji and rofi-calc from the image.

**Architecture:** Five new surfaces inside the existing shell config (`profile/airootfs/etc/skel/.config/quickshell/`), each following the launcher's proven pattern — LazyLoader popup + `IpcHandler` target + hyprland.lua bind via `qs ipc call`. Notifications add a `NotificationServer` plus a bar chip. Every external action goes through argv arrays or `Process.write` stdin — never a composed shell string.

**Tech Stack:** quickshell 0.3.1 (`Quickshell.Services.Notifications`, `Quickshell.Hyprland` toplevels, `Quickshell.Io`), `qalc` (libqalculate), `cliphist`, `wl-copy`. bats + the established policy tests; the QEMU harness for the VM task.

**Spec:** `docs/superpowers/specs/2026-08-31-shell-surfaces-2.md`

## Global Constraints

- Branch `shell/quickshell-2` off main after the installer plan merges. Author `edbron <edbron411@gmail.com>`.
- IPC targets, exact: `notify` (fn `dnd`), `winswitch` (fn `toggle`), `emoji` (fn `toggle`), `calc` (fn `toggle`), `clip` (fn `toggle`). hyprland.lua binds: Super+Tab→winswitch, Super+period→emoji, Super+equal→calc, Super+X→clip — each `hl.dsp.exec_cmd("qs ipc call <t> toggle")`.
- **No composed shell strings anywhere.** The old Super+X pipe (`cliphist list | rofi … | cliphist decode | wl-copy`) is replaced by: `cliphist list` via Process → selection line written to `cliphist decode`'s stdin via `Process.write` → its stdout collected → written to `wl-copy`'s stdin. A test greps the tree for `"sh", "-c"` and fails on any hit.
- Popup pattern is the launcher's: centred focusable PanelWindow (560×420 default), filter TextField with `Keys.onPressed` navigation, `closeRequested()` signal wired in shell.qml, `ScriptModel { comparisonMode: ObjectComparison.Identity }` for any filtered list (the delegate-churn lesson), filter resets on open via LazyLoader recreate.
- Policy gates already cover the shell dir: `\uXXXX` glyphs, no hex outside Theme.qml, qmllint. New files inherit them automatically — do not weaken the tests.
- Removals proven by grep: after Task 5, `grep -rn 'rofi\|mako' profile/` returns nothing (comments included). `packages.x86_64`: −rofi −rofi-emoji −rofi-calc −mako, +libqalculate. `cyberos-theme`: mako block + `makoctl reload` line and rofi colors.rasi block + `rofi` mkdir component removed; `hyprland.lua`: the rofi layer_rule deleted, the four binds swapped.
- Emoji data: `profile/airootfs/etc/skel/.config/quickshell/emoji.txt`, generated ONCE by the implementer from the rofi-emoji package's `all_emojis.txt` (extract with bsdtar from `pacman -Sp rofi-emoji`'s file; the package cannot ship — it depends on rofi). File header comment: source + CC-BY-4.0 Unicode attribution. Format preserved: `<emoji> <name> [keywords]` per line.
- Runner `/tmp/claude-1000/-home-edbron-Work/9fdca27c-4540-4321-9795-683d0bdd0a18/scratchpad/bats-core/bin/bats`; full `tests/` green each commit. Host smoke per task with the extracted qs (`QML2_IMPORT_PATH=<scratchpad>/qs/usr/lib/qt6/qml`, binary `<scratchpad>/qs/usr/bin/qs`), `pkill -x qs` only, grim banned while a layer-shell qs runs (hyprctl evidence instead).
- Session hard rules: env() null truthiness; `onFileChanged: reload()` for watched files; never `pkill -f`.

## File Structure

New, under `profile/airootfs/etc/skel/.config/quickshell/`:

| File | Responsibility |
|---|---|
| `notify/NotifyPopups.qml` | top-right stacked popup column over `server.trackedNotifications` |
| `notify/NotifyCard.qml` | one notification: icon/appName/body/actions/urgency styling, click dismiss |
| `bar/NotifyChip.qml` | bar chip: DND state + tracked count; click toggles DND |
| `popups/WinSwitch.qml` | Hyprland.toplevels list, cycle+activate |
| `popups/EmojiPicker.qml` | grid over emoji.txt, filter, copy on Return |
| `popups/Calc.qml` | qalc-backed evaluator, copy result |
| `popups/ClipHist.qml` | cliphist list/filter/decode-copy |
| `emoji.txt` | vendored data |

Modified: `shell.qml` (server + 5 loaders + 5 IpcHandlers + DND state), `bar/Bar.qml` (NotifyChip), `hyprland.lua`, `cyberos-theme`, `packages.x86_64`, deletions (`etc/skel/.config/mako/`, `etc/skel/.config/rofi/`). Tests: extend `tests/quickshell.bats` + `tests/hyprland-lua.bats`; new `tests/surfaces2.bats`.

---

### Task 1: Notification server, popups, DND chip; mako removed

**Files:** Create `notify/NotifyPopups.qml`, `notify/NotifyCard.qml`, `bar/NotifyChip.qml`; modify `shell.qml`, `bar/Bar.qml`, `profile/airootfs/usr/local/bin/cyberos-theme`, `profile/packages.x86_64`; delete `profile/airootfs/etc/skel/.config/mako/`; test `tests/surfaces2.bats`.
**Interfaces produced:** `shell.qml`: `NotificationServer { id: notifServer; keepOnReload: true; actionsSupported: true; imageSupported: true; bodySupported: true; onNotification: n => n.tracked = true }` (verify the exact tracking idiom against the qmltypes/upstream examples — the server must accept and track); `property bool dnd` + `IpcHandler { target: "notify"; function dnd(): void }`; NotifyChip reads `notifServer.trackedNotifications.values.length` and `dnd`.

- [ ] **Tests first** (`tests/surfaces2.bats`):

```bash
#!/usr/bin/env bats
ROOT="$BATS_TEST_DIRNAME/.."
QS="$ROOT/profile/airootfs/etc/skel/.config/quickshell"

@test "notification server replaces mako" {
  grep -q 'NotificationServer' "$QS/shell.qml"
  grep -q '"notify"' "$QS/shell.qml"
  [ ! -d "$ROOT/profile/airootfs/etc/skel/.config/mako" ]
  ! grep -qE '^mako$' "$ROOT/profile/packages.x86_64"
  ! grep -rn 'mako' "$ROOT/profile/airootfs/usr/local/bin/cyberos-theme"
  ! grep -rn 'mako' "$ROOT/profile/airootfs/etc/skel/.config/hypr/hyprland.lua"
  [ -f "$QS/notify/NotifyCard.qml" ] && grep -q 'Theme.alert' "$QS/notify/NotifyCard.qml"
  grep -q 'invoke' "$QS/notify/NotifyCard.qml"
}
```

Also update `tests/hyprland-lua.bats`'s autostart expectations (mako autostart gone) — controller ruling R2 applies: the whole suite green at task end.
- [ ] Implement per the spec's §1 (urgency: critical no-expire + alert border; ~6 s default expire via each card's Timer honouring `expireTimeout` when >0; click dismisses via `notification.dismiss()`; actions row invoking `NotificationAction.invoke()`; popups top-right anchored PanelWindow column, `exclusiveZone: 0`, hidden when empty or DND). Remove the mako autostart from hyprland.lua, the mako block + `makoctl reload` from cyberos-theme, the config dir, the package. Host smoke: launch qs, `notify-send -u critical test body` + `notify-send action test` (`gdbus`/notify-send available on host), verify cards appear (hyprctl layers + zero warnings), DND via `qs ipc call notify dnd` hides them. Commit `"shell: QML notifications replace mako"`.

### Task 2: Window switcher

**Files:** Create `popups/WinSwitch.qml`; modify `shell.qml`, `hyprland.lua`; extend tests.
**Interfaces:** `IpcHandler { target: "winswitch"; function toggle(): void }`; Super+Tab bind swapped.

- [ ] Tests: bind assertion via the hl-stub capture (`SUPER + Tab` dispatches `qs ipc call winswitch toggle`; `rofi -show window` gone); `grep -q 'Hyprland.toplevels' popups/WinSwitch.qml`.
- [ ] Implement: list rows `title — appId (ws N)` from `Hyprland.toplevels.values` (HyprlandToplevel: `title`, `lastIpcObject` for class/workspace; activation — check the qmltypes for an `activate()`; else `Hyprland.dispatch("hl.dsp.focus({window=...})")` addressing by the toplevel's address from lastIpcObject, verified at runtime); Tab/arrows cycle, Return activates+closes, Escape closes. Smoke with two windows open. Commit `"shell: QML window switcher replaces rofi window"`.

### Task 3: Emoji picker (+vendored data)

**Files:** Create `popups/EmojiPicker.qml`, `emoji.txt`; modify `shell.qml`, `hyprland.lua`; extend tests.
- [ ] Tests: `[ -s "$QS/emoji.txt" ]` and header attribution grep; bind swap assertion; `! grep -qE '^rofi-emoji$' packages.x86_64` (moved here from T5 if convenient — coordinate: the package line is removed in THIS task since its data is vendored now).
- [ ] Implement: parse emoji.txt lines (`FileView` read once — split on first space: emoji, rest = searchable text), GridView 8 columns of emoji glyphs (they are normal Unicode, NOT PUA — the policy test only bans PUA; state this in a comment), filter over names/keywords, Return → write the emoji to `wl-copy` stdin via Process.write, close. Generate emoji.txt per Global Constraints. Commit `"shell: QML emoji picker; data vendored from rofi-emoji"`.

### Task 4: Calculator + clipboard history

**Files:** Create `popups/Calc.qml`, `popups/ClipHist.qml`; modify `shell.qml`, `hyprland.lua`, `packages.x86_64` (+libqalculate, −rofi-calc); extend tests.
- [ ] Tests: binds swapped (equal→calc, X→clip); `grep -q '"qalc"' popups/Calc.qml`; `grep -qE '^libqalculate$' packages.x86_64`; the no-shell-strings test: `! grep -rn '"sh", "-c"' "$QS"`; cliphist decode via stdin: `grep -q 'write(' popups/ClipHist.qml`.
- [ ] Implement Calc: TextField expression → debounce Timer 150 ms → `Process { command: ["qalc","-t",expr] }` (expr as ONE argv element — qalc takes the expression as an argument; this is argv, not a shell string, acceptable), result Text; Return → result to wl-copy stdin, close. ClipHist: `cliphist list` → ScriptModel rows (id\tpreview), filter, Return → selected FULL line written via Process.write to `cliphist decode` stdin, its StdioCollector output written to `wl-copy` stdin (chain the two Processes), close. Smoke both (calc `2+2`→4 visible; clipboard round-trip: `wl-copy hello` beforehand, pick it, `wl-paste` shows hello). Commit `"shell: QML calculator and clipboard history"`.

### Task 5: rofi eradication + seam wiring

**Files:** Modify `hyprland.lua` (delete the rofi layer_rule), `cyberos-theme` (rofi colors block + mkdir component), `packages.x86_64` (−rofi), delete `profile/airootfs/etc/skel/.config/rofi/`; extend tests.
- [ ] Tests: `! grep -rn 'rofi' "$ROOT/profile/"` (the complete-removal gate — run it and fix every hit this grep finds, including comments); `! grep -qE '^rofi$' packages.x86_64`; suite-wide: all hl-stub bind captures still green; launcher/apps-chip unaffected.
- [ ] Implement the removals; re-run the FULL suite; host smoke: everything still loads with zero warnings. Commit `"shell: rofi fully removed; five QML surfaces own its roles"`.

### Task 6: VM verification (controller-run)

Deliver the changed tree into the build-16 VM via cfg ISO (files + libqalculate pkg + its deps for pacman -U, as before); restart session; drive each surface with real keybinds (Super+Tab with two windows, Super+period type "smile" copy, Super+equal type 2+2, Super+X after wl-copy seeding, notify-send critical + action + DND toggle + chip count); screenshot each; record in `docs/branches/shell-quickshell-2.md`; push, PR.

## Self-Review
- Spec §1–§5 → T1–T5; VM → T6; removals distributed (mako T1, rofi-emoji T3, rofi-calc T4, rofi T5) with T5 as the final gate. ✓
- No placeholders; the two runtime-verification deferrals (notification tracking idiom, toplevel activation) are named checks with fallbacks, matching how prior plans handled 0.3.1 gaps. ✓
- IPC names consistent between Global Constraints, tasks and tests. ✓
- Risk noted: emoji grid size (~1900 rows) — ScriptModel identity + GridView virtualisation should hold; T3 smoke must scroll it.
