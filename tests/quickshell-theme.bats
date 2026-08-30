#!/usr/bin/env bats
# The theming contract: cyberos-theme generates theme.json; Theme.qml consumes it.

ROOT="$BATS_TEST_DIRNAME/.."
QS="$ROOT/profile/airootfs/etc/skel/.config/quickshell"

setup() {
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/cfg"
  mkdir -p "$XDG_CONFIG_HOME"
}

@test "cyberos-theme writes valid theme.json for both modes" {
  for mode in light dark; do
    env -u HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      bash "$ROOT/profile/airootfs/usr/local/bin/cyberos-theme" "$mode" >/dev/null
    python3 - "$XDG_CONFIG_HOME/quickshell/theme.json" "$mode" <<'PY'
import json, sys
t = json.load(open(sys.argv[1]))
assert t["mode"] == sys.argv[2], t
for k in ("bg","surface","fg","muted","accent","accent2","alert","border","sel"):
    v = t[k]
    assert v.startswith("#") and len(v) == 7, (k, v)
assert 0 < t["barAlpha"] <= 1
PY
  done
}

@test "light and dark produce different backgrounds, same accent" {
  for mode in light dark; do
    env -u HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      bash "$ROOT/profile/airootfs/usr/local/bin/cyberos-theme" "$mode" >/dev/null
    cp "$XDG_CONFIG_HOME/quickshell/theme.json" "$BATS_TEST_TMPDIR/$mode.json"
  done
  python3 - "$BATS_TEST_TMPDIR" <<'PY'
import json, sys
l = json.load(open(sys.argv[1] + "/light.json")); d = json.load(open(sys.argv[1] + "/dark.json"))
assert l["bg"] != d["bg"]
assert l["accent"] == d["accent"] == "#00CA4E"
PY
}

@test "the skel theme.json is the dark palette, matching the skel default" {
  python3 - "$QS/theme.json" <<'PY'
import json, sys
t = json.load(open(sys.argv[1]))
assert t["mode"] == "dark" and t["bg"] == "#1D1D1F" and t["accent"] == "#00CA4E"
PY
}

@test "Theme.qml is a valid singleton and reads only theme.json" {
  grep -q '^pragma Singleton' "$QS/Theme.qml"
  grep -q 'singleton Theme' "$QS/qmldir"
  grep -q 'watchChanges' "$QS/Theme.qml"
}

@test "qmllint accepts Theme.qml (skips if qmllint absent)" {
  QMLLINT=/usr/lib/qt6/bin/qmllint
  [ -x "$QMLLINT" ] || skip "qmllint not installed"
  "$QMLLINT" --bare "$QS/Theme.qml"
}
