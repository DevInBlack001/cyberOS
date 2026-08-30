#!/usr/bin/env bats
# Executes hyprland.lua against a stub `hl` that records calls. A config that
# parses but registers no binds trips Hyprland's emergency mode, so parsing is
# not enough.

HYPR="$BATS_TEST_DIRNAME/../profile/airootfs/etc/skel/.config/hypr"
STUB="$BATS_TEST_DIRNAME/hl-stub.lua"

setup() {
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/cfg"
  mkdir -p "$XDG_CONFIG_HOME/hypr"
  cp "$HYPR/theme.lua" "$XDG_CONFIG_HOME/hypr/theme.lua"
}

run_config() { lua -e "dofile('$STUB'); dofile('$HYPR/hyprland.lua'); report()"; }

@test "hyprland.lua and theme.lua are valid Lua" {
  luac -p "$HYPR/hyprland.lua" "$HYPR/theme.lua"
}

@test "the config registers the core binds" {
  run run_config
  [ "$status" -eq 0 ]
  [[ "$output" == *"bind SUPER + Return"* ]]
  [[ "$output" == *"bind SUPER + SHIFT + T"* ]]
  [[ "$output" == *"bind SUPER + I"* ]]
  [[ "$output" == *"bind SUPER + 1"* ]]
  [[ "$output" == *"bind SUPER + SHIFT + 0"* ]]
  [[ "$output" == *"bind Print"* ]]
}

@test "enough binds to never trip emergency mode" {
  run run_config
  n=$(grep -c '^bind ' <<<"$output")
  [ "$n" -ge 60 ]
}

@test "autostart launches the bar, notifications and idle daemon" {
  run run_config
  [[ "$output" == *"exec waybar"* ]]
  [[ "$output" == *"exec mako"* ]]
  [[ "$output" == *"exec hypridle"* ]]
}

@test "border colours come from theme.lua, not from the config" {
  run run_config
  [[ "$output" == *"active_border=rgb(00CA4E)"* ]]
  ! grep -qE 'rgb\([0-9A-F]{6}\)' <<<"$(grep -v 'fallback\|theme = {' "$HYPR/hyprland.lua" | grep -v '^--')" \
    || { echo "hex colours found in hyprland.lua; they belong in cyberos-theme"; false; }
}

@test "a missing theme.lua degrades to the fallback palette instead of failing" {
  rm "$XDG_CONFIG_HOME/hypr/theme.lua"
  run run_config
  [ "$status" -eq 0 ]
  [[ "$output" == *"active_border=rgb(00CA4E)"* ]]
}

@test "cyberos-theme generates a theme.lua that hyprland.lua consumes, both modes" {
  for mode in light dark; do
    env -u HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      bash "$BATS_TEST_DIRNAME/../profile/airootfs/usr/local/bin/cyberos-theme" "$mode" >/dev/null
    luac -p "$XDG_CONFIG_HOME/hypr/theme.lua"
    run run_config
    [ "$status" -eq 0 ]
    [[ "$output" == *"active_border=rgb(00CA4E)"* ]]
    grep -q "mode    = \"$mode\"" "$XDG_CONFIG_HOME/hypr/theme.lua"
  done
}

@test "the legacy hyprland.conf is gone, so the two cannot drift" {
  [ ! -e "$HYPR/hyprland.conf" ]
}

@test "volume/brightness binds dispatch through the quickshell OSD ipc, swayosd gone" {
  run run_config
  [[ "$output" == *"bindcmd XF86AudioRaiseVolume :: qs ipc call osd volumeUp"* ]]
  [[ "$output" == *"bindcmd XF86AudioLowerVolume :: qs ipc call osd volumeDown"* ]]
  [[ "$output" == *"bindcmd XF86AudioMute :: qs ipc call osd volumeMute"* ]]
  [[ "$output" == *"bindcmd XF86MonBrightnessUp :: qs ipc call osd brightnessUp"* ]]
  [[ "$output" == *"bindcmd XF86MonBrightnessDown :: qs ipc call osd brightnessDown"* ]]
  ! grep -q swayosd <<<"$output"
}
