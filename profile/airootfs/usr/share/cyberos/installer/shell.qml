//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "." as Cyber

// CyberOS installer wizard -- Quickshell replacement for the GTK4/libadwaita
// cyberos-install-gui. The one rule carried over unchanged: this config does
// no disk work of its own. It only collects answers into WizState; a later
// task's install page runs `sudo -n cyberos-install ... --password-stdin
// --yes` with secrets over Process.write(), never on argv.
//
// FloatingWindow (Quickshell._Window, default-imported by `import
// Quickshell`) rather than a PanelWindow/layer surface: this is a normal
// application window like the GTK Adw.ApplicationWindow it replaces, not a
// shell surface.
ShellRoot {
    FloatingWindow {
        id: window
        title: "Install CyberOS"
        implicitWidth: 720
        implicitHeight: 560
        visible: true
        color: Cyber.Theme.bg

        // Set true once the /run/archiso guard below decides this is not
        // live media. Dry-run always skips the guard entirely -- same as the
        // GTK wizard's `if not DRY_RUN and not os.path.isdir("/run/archiso")`.
        property bool blocked: false

        // ---------------------------------------------------------- guard
        // Same check InstallButton.qml uses on the bar. Non-zero exit means
        // /run/archiso is missing, i.e. this is not the live medium.
        Process {
            id: archisoCheck
            command: ["test", "-d", "/run/archiso"]
            onExited: exitCode => { if (exitCode !== 0) window.blocked = true; }
        }

        Component.onCompleted: {
            if (!Cyber.WizState.dryRun) archisoCheck.running = true;
        }

        // ------------------------------------------------------- wizard UI
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            visible: !window.blocked

            Rectangle {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: Cyber.Theme.surface

                Rectangle {
                    id: backBtn
                    visible: !["welcome", "install", "done"].includes(Cyber.WizState.page)
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: backLabel.implicitWidth + 24
                    height: 30
                    radius: Cyber.Theme.radius / 2
                    color: backArea.containsMouse ? Cyber.Theme.sel : "transparent"
                    border.width: 1
                    border.color: Cyber.Theme.border

                    Text {
                        id: backLabel
                        anchors.centerIn: parent
                        text: "Back"
                        color: Cyber.Theme.fg
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                    }
                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Cyber.WizState.back()
                    }
                }

                Rectangle {
                    id: nextBtn
                    visible: !["install", "done"].includes(Cyber.WizState.page)
                    enabled: pageLoader.item ? pageLoader.item.ready : true
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: nextLabelText.implicitWidth + 24
                    height: 30
                    radius: Cyber.Theme.radius / 2
                    color: nextBtn.enabled ? Cyber.Theme.accent : Cyber.Theme.border
                    opacity: nextBtn.enabled ? 1 : 0.5

                    Text {
                        id: nextLabelText
                        anchors.centerIn: parent
                        text: pageLoader.item ? pageLoader.item.nextLabel : "Next"
                        color: Cyber.Theme.bg
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize; bold: true }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Cyber.WizState.next()
                    }
                }
            }

            // Page name -> file convention: "welcome" -> pages/WelcomePage.qml.
            // Only WelcomePage and DonePage exist in this skeleton task; the
            // rest arrive in later tasks (disk, mode, custom, account,
            // options, confirm, install).
            Loader {
                id: pageLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: "pages/" + Cyber.WizState.page.charAt(0).toUpperCase()
                        + Cyber.WizState.page.slice(1) + "Page.qml"
            }
        }

        // ---------------------------------------------------- guard message
        // Copy text verbatim from the GTK wizard's main()'s Gtk.AlertDialog.
        Rectangle {
            anchors.fill: parent
            visible: window.blocked
            color: Cyber.Theme.bg

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.7
                spacing: 12

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "CyberOS is already installed"
                    color: Cyber.Theme.fg
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 6; bold: true }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "The installer only runs from the CyberOS live USB."
                    color: Cyber.Theme.muted
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
            }
        }
    }
}
