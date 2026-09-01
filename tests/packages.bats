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
  for p in udisks2 xdg-desktop-portal-kde adwaita-cursors; do
    pkg_listed "$p"
  done
}

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
