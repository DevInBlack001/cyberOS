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

    // Same command as the .desktop Exec and the Super+I bind -- gtk-launch
    // left with GTK. List form: no shell, no quoting pitfalls.
    onClicked: Quickshell.execDetached(["foot", "--app-id=cyberos-installer", "--title=Install CyberOS", "sudo", "/usr/local/bin/cyberos-install"])
}
