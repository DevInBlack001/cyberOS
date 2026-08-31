# Branch: `theme/macos-palette`

**State:** merged into `main` via PR #3 · **Owner:** @edbron

## Charter

One palette across every surface of the OS, switchable between light and dark by the
student, dark by default.

## The palette

| Name | Hex | Role |
|---|---|---|
| Red Shimmer | `#FF605C` | alerts, errors, urgent |
| Coronation Gold | `#FFBD44` | warnings, secondary accent |
| Malachite | `#00CA4E` | primary accent, focus, active border |
| Light Silver | `#E1DFE1` | light-mode surface, dark-mode muted text |
| Argent | `#C0BFC0` | borders, muted |
| Tech White | `#F5F5F5` | light background, dark foreground |

Dark mode adds `#1D1D1F` background, `#2B2B2D` surface, `#3A3A3C` border. ANSI terminal
colours additionally need blue `#0A84FF`, magenta `#BF5AF2`, cyan `#5AC8FA` — the six
brand colours cannot express a 16-colour palette on their own.

## Scope

| Path | Role |
|---|---|
| `usr/local/bin/cyberos-theme` | **The single source of truth.** Generates every config below. |
| `etc/skel/.config/hypr/theme.conf` | generated |
| `etc/skel/.config/quickshell/theme.json` | generated (superseded `waybar/colors.css` when the bar moved to Quickshell) |
| `etc/skel/.config/rofi/colors.rasi` | generated |
| `etc/skel/.config/foot/foot.ini` | generated **wholesale** |
| `etc/skel/.config/mako/config` | generated |
| `etc/skel/.config/tmux/theme.conf` | generated |
| `etc/skel/.config/nvim/lua/cyber_colors.lua` | generated |
| `assets/wallpaper*.svg` + rendered PNGs | per-mode wallpapers |
| `usr/share/sddm/themes/pixie/` | greeter |

## The rule that defines this branch

**Colours are defined once, in `cyberos-theme`, and nowhere else.** No hex value belongs in
a hand-written config file. `Super+Shift+T` toggles, and every surface must follow —
including a terminal opened *after* the toggle.

## Traps this branch already hit

- **`hyprland.conf` hardcoded its border colours** and ignored `theme.conf`. Now
  `col.active_border = $accent`, `col.inactive_border = $border`.
- **foot's `include=` is only valid at top level and does not expand `~`.** The script
  writes `foot.ini` wholesale instead.
- **Emitting distinct `[colors-light]` and `[colors-dark]` sections is wrong for us.** foot
  then chooses between them via the appearance portal, and with no portal running it
  defaults to dark — so terminals came up dark in light mode. Write the **active** palette
  into *both* sections. **Done** (`theme/foot-portal`, PR #5).
- **Waybar restart races** (historical, pre-Quickshell). `pkill -x waybar; sleep 0.4;
  (setsid waybar &)`. The Quickshell bar has no such race: `Theme.qml` watches
  `theme.json` and re-themes live, no restart needed.
- **The wallpapers use a radial gradient with two stops.** Recolouring only one leaves them
  green.
- **Never rewrite `waybar/config.jsonc` by hand.** It carries 23 private-use-area glyphs that
  are invisible in tool output and were lost once already. Edit at byte level and check the
  PUA count before and after.

## Follow-up work

- ~~Port `hyprland.conf` to the Lua config format.~~ **Done** (`theme/lua-config`).
  `hyprland.lua` loads its palette from a generated `theme.lua` with a hardcoded fallback so
  a missing file degrades instead of tripping emergency mode; `theme.conf` is still
  generated because `hyprlock` speaks hyprlang. The `.conf` was deleted, not kept alongside,
  so the two formats cannot drift. Tested by executing the config against a stub `hl` and
  asserting the binds, autostarts and palette it registers (`tests/hyprland-lua.bats`), and
  verified in a running session on the build-15 install: 69 binds registered, the border
  colour arriving from `theme.lua`, and the deprecation banner gone.
