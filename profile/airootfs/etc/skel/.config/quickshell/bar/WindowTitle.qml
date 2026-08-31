import QtQuick
import Quickshell.Hyprland
import ".." as Cyber

Text {
    // "top" collides with QQuickItem's own FINAL anchor-line property (Qt 6.9+),
    // so this cannot be named "top" -- use "activeToplevel" instead.
    property var activeToplevel: Hyprland.activeToplevel
    text: activeToplevel ? (activeToplevel.title + " - " + (activeToplevel.lastIpcObject?.class ?? "")) : ""
    // A window's title is set by whatever app owns it, not by this desktop;
    // Text's default AutoText format would render HTML-like content in a
    // title as markup in the system bar.
    textFormat: Text.PlainText
    elide: Text.ElideRight
    width: Math.min(implicitWidth, 480)
    color: Cyber.Theme.muted
    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
}
