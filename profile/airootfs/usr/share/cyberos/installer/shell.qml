//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "." as Cyber

// CyberOS installer wizard -- Quickshell replacement for the previous
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

        // Tri-state, not a bool: the archiso check resolves asynchronously
        // (Process is never synchronous), so a bool defaulting to "not
        // blocked" let the full wizard render for one or more frames on an
        // already-installed machine before the guard below caught up --
        // exactly the leak the guard exists to prevent. "checking" renders
        // neither the wizard nor the guard message (a blank themed window)
        // until the check (or dryRun) resolves it one way or the other.
        // Dry-run always skips the guard entirely -- same as the GTK
        // wizard's `if not DRY_RUN and not os.path.isdir("/run/archiso")`.
        property string guardState: Cyber.WizState.dryRun ? "ok" : "checking"

        // ---------------------------------------------------------- guard
        // Same check InstallButton.qml uses on the bar. Non-zero exit means
        // /run/archiso is missing, i.e. this is not the live medium.
        //
        // Spawn-failure fallback, same idiom Probe.qml's every Process
        // already uses (see its file-level comment for why): if `test`
        // itself fails to spawn, this build never emits `exited`, only
        // `runningChanged` going straight to false -- so onExited alone
        // would leave guardState stuck on "checking" forever (a blank
        // themed window, the exact leak the tri-state exists to prevent).
        // `onRunningChanged` resolves that case to "blocked", not "ok": an
        // unverifiable guard must fail safe as "not the live medium" rather
        // than silently let the destructive wizard render.
        Process {
            id: archisoCheck
            property bool _resolved: false
            command: ["test", "-d", "/run/archiso"]
            onExited: exitCode => {
                archisoCheck._resolved = true;
                window.guardState = exitCode === 0 ? "ok" : "blocked";
            }
            onRunningChanged: {
                if (running || archisoCheck._resolved) return;
                archisoCheck._resolved = true;
                window.guardState = "blocked";
            }
        }

        Component.onCompleted: {
            if (!Cyber.WizState.dryRun) archisoCheck.running = true;
        }

        // ------------------------------------------------------- wizard UI
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            visible: window.guardState === "ok"

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
                    border.width: backBtn.activeFocus ? 2 : 1
                    border.color: backBtn.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                    // Keyboard-operable, not just mouse: Tab reaches this
                    // button (skipped automatically while !visible, same as
                    // every focusable QtQuick.Controls item already used
                    // elsewhere in this wizard), Return/Enter activates it
                    // exactly like a click.
                    activeFocusOnTab: true
                    Keys.onReturnPressed: Cyber.WizState.back()
                    Keys.onEnterPressed: Cyber.WizState.back()

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
                    border.width: nextBtn.activeFocus ? 2 : 0
                    border.color: Cyber.Theme.fg
                    // Same keyboard-operable pattern as backBtn above.
                    // `enabled: false` already keeps a disabled Next out of
                    // the tab chain and blind to key events, same as any
                    // other disabled QtQuick item -- no extra guard needed
                    // in the handlers below.
                    activeFocusOnTab: true
                    Keys.onReturnPressed: Cyber.WizState.next()
                    Keys.onEnterPressed: Cyber.WizState.next()

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
        // Copy text verbatim from the GTK wizard's main()'s alert dialog.
        Rectangle {
            anchors.fill: parent
            visible: window.guardState === "blocked"
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
