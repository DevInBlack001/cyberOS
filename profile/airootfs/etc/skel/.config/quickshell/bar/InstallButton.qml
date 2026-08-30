import QtQuick
import Quickshell
import Quickshell.Io
import ".." as Cyber

BarModule {
    id: installBtn
    property bool isLiveIso: false
    visible: isLiveIso

    Process {
        id: installCheck
        command: ["test", "-d", "/run/archiso"]
        running: true
        onExited: exitCode => installBtn.isLiveIso = (exitCode === 0)
    }

    icon: "\uf019"
    label: "Install CyberOS"
    iconColor: Cyber.Theme.accent2
    labelColor: Cyber.Theme.accent2

    onClicked: Quickshell.execDetached(["gtk-launch", "cyberos-install"])
}
