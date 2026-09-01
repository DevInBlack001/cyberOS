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
