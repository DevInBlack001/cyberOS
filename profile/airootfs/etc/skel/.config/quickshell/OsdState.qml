pragma Singleton
import QtQuick
import Quickshell

// Bridges shell.qml's `IpcHandler { target: "osd" }` to osd/Osd.qml.
//
// osd/Osd.qml is instantiated through a LazyLoader, and QML id scoping means
// it cannot see any id declared in shell.qml (the same problem PowerMenu.qml
// solved, for the opposite direction, with a `closeRequested` signal). A
// singleton sidesteps it entirely: Osd.qml just imports this file like it
// imports Theme.
//
// It also sidesteps the `activeAsync` race the plan called out: writing to
// `osd.item.level` right after `osd.activeAsync = true` can run before the
// item exists (activeAsync is asynchronous). Osd.qml instead *binds* to
// these properties, so whatever they hold at the moment the PanelWindow is
// actually created is what it renders -- the write/create order no longer
// matters.
//
// `seq` is a monotonic "please (re)show" trigger, separate from level/icon:
// pressing volume-up at 100%, or toggling mute twice, can leave level and
// icon unchanged but must still re-show the OSD and restart its hide timer.
Singleton {
    id: root

    property real level: 0
    property string icon: ""
    property int seq: 0
}
