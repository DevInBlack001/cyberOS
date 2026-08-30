import QtQuick
import Quickshell.Services.Mpris

BarModule {
    id: media
    readonly property var browsers: ["firefox", "chromium", "brave"]
    property var player: Mpris.players.values.find(p =>
        !browsers.some(b => p.desktopEntry?.includes(b))) ?? null

    visible: player !== null
    icon: "\uf001"
    label: player ? elide(player.trackArtist + " - " + player.trackTitle, 35) : ""
    tooltip: player ? player.identity : ""

    function elide(text, max) {
        return text.length > max ? text.slice(0, max - 1) + "…" : text;
    }

    onClicked: player?.togglePlaying()
}
