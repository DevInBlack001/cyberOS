import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import ".." as Cyber

BarModule {
    id: audio
    property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [audio.sink] }

    property real vol: sink?.audio.volume ?? 0
    property bool muted: sink?.audio.muted ?? false
    // volume-xmark (muted) / volume-up / volume-down / volume-off (near-zero)
    icon: muted ? "\ueee8" : vol > 0.66 ? "\uf028" : vol > 0.33 ? "\uf027" : "\uf026"
    iconColor: muted ? Cyber.Theme.muted : Cyber.Theme.fg
    tooltip: "Playing at " + Math.round(vol * 100) + "%"

    onClicked: button => {
        if (button === Qt.RightButton) { if (sink) sink.audio.muted = !muted }
        else Quickshell.execDetached(["pavucontrol"])
    }
    onScrolled: delta => {
        if (sink) sink.audio.volume = Math.max(0, Math.min(1, vol + delta * 0.05))
    }
}
