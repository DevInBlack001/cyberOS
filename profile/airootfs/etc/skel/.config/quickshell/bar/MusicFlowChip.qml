import QtQuick
import Quickshell
import ".." as Cyber

// Replaces the old single-line Media.qml: reads its player from
// popups/MusicFlow.qml (musicflow.item) rather than recomputing its own
// filtered player list, the same cross-id-reference shape
// bar/NotifyChip.qml and bar/SystemHealthChip.qml already use -- so the
// chip and the panel's own multi-source selector can never disagree about
// which player is "active". Left-click opens the panel (track info,
// playback controls, source selector) instead of toggling play/pause
// directly here.
BarModule {
    id: chip

    readonly property var player: musicflow.item ? musicflow.item.player : null

    visible: player !== null
    icon: "\uf001" // fa-music
    label: player ? elide((player.trackArtist ? player.trackArtist + " - " : "") + player.trackTitle, 35) : ""
    tooltip: player ? player.identity : ""

    function elide(text, max) {
        return text.length > max ? text.slice(0, max - 1) + "…" : text;
    }

    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "musicflow", "toggle"])
}
