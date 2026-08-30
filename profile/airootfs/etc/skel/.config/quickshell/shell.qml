//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "." as Cyber
import "bar" as Bar
import "power" as Power

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Bar.Bar { required property var modelData; screen: modelData }
    }

    // Popup surfaces land here (osd/launcher in later tasks). LazyLoader
    // keeps startup cheap and a broken popup from taking the bar down.
    LazyLoader {
        id: powerMenu
        Power.PowerMenu { onCloseRequested: powerMenu.active = false }
    }
    LazyLoader { id: launcher; }
    LazyLoader { id: osd; }

    // `qs ipc call power toggle` opens the menu if closed, closes it if open.
    IpcHandler {
        target: "power"
        function toggle(): void {
            powerMenu.activeAsync ? powerMenu.active = false : powerMenu.activeAsync = true
        }
    }
}
