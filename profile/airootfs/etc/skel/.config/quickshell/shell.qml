//@ pragma UseQApplication
import QtQuick
import Quickshell
import "." as Cyber
import "bar" as Bar

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Bar.Bar { required property var modelData; screen: modelData }
    }

    // Popup surfaces land here in later tasks. LazyLoader keeps startup cheap
    // and a broken popup from taking the bar down.
    LazyLoader { id: powerMenu; }
    LazyLoader { id: launcher; }
    LazyLoader { id: osd; }
}
