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

@test "images: pans via a transform, with the MouseArea outside it" {
  f="$QS/apps/Images.qml"
  grep -q 'Translate' "$f"
  grep -q 'pan.x' "$f"
  # anchors beat x/y, so a drag target on the anchored image is dead code
  run grep 'drag.target' "$f"
  [ "$status" -ne 0 ]
  # The MouseArea must NOT be nested inside the Image that carries the
  # Translate: Qt would deliver it already-transformed coordinates and the
  # pan math would double-compensate. Assert the Image element contains no
  # MouseArea by checking the span from `Image {` to the line before the
  # MouseArea declaration never opens one.
  img_line=$(grep -n 'Image {' "$f" | head -1 | cut -d: -f1)
  ma_line=$(grep -n 'MouseArea {' "$f" | head -1 | cut -d: -f1)
  [ "$ma_line" -gt "$img_line" ]
  # the Image block must have closed before the MouseArea opens: at the
  # MouseArea's indentation, a nested one would be deeper than the Image's.
  img_indent=$(sed -n "${img_line}p" "$f" | sed 's/[^ ].*//' | wc -c)
  ma_indent=$(sed -n "${ma_line}p" "$f" | sed 's/[^ ].*//' | wc -c)
  [ "$ma_indent" -le "$img_indent" ]
}

@test "images: ipc open target and desktop entry at an unowned path" {
  grep -q 'target: "images"' "$QS/shell.qml"
  grep -q 'function open' "$QS/shell.qml"
  d="$ROOT/profile/airootfs/usr/local/share/applications/cyberos-images.desktop"
  [ -f "$d" ]
  grep -q 'Exec=cyberos-images %f' "$d"
  grep -q 'MimeType=image/' "$d"
}

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
  grep -q 'Exec=cyberos-files %f' "$d"
  grep -q 'MimeType=inode/directory' "$d"
}

@test "launcher wrappers pass an explicit argument and are mode-registered" {
  for w in cyberos-files cyberos-images; do
    f="$ROOT/profile/airootfs/usr/local/bin/$w"
    [ -f "$f" ]
    # The empty-default is the whole point: qs ipc call with too few
    # arguments silently does nothing.
    grep -q '"${1:-}"' "$f"
    # mkarchiso copies airootfs with --no-preserve=mode, so the execute bit
    # only exists if profiledef.sh declares it.
    grep -q "\"/usr/local/bin/$w\"\]=\"0:0:755\"" "$ROOT/profile/profiledef.sh"
  done
}
