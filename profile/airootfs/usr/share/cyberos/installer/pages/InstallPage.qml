import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".." as Cyber

// Ported verbatim from the GTK wizard's page_install() (~383-393),
// start_install()/read_line()/on_line()/on_exit()/finish() (~528-605)
// (cyberos-install-gui). The GTK original merged stdout+stderr into one
// pipe (Gio.SubprocessFlags.STDERR_MERGE); Quickshell's Process has no such
// flag, so both streams get their own SplitParser here, each appending to
// the same log -- the observable result (one interleaved log) is the same,
// even though the two streams are no longer guaranteed byte-interleaved in
// original order the way a real merged pipe would be.
//
// The GTK original used a pulsing progress bar with set_text() as its
// status line; this page's `status` Text is the direct replacement, same
// three states ("Installing…" / "Done" / "Failed (exit N)"), without the
// pulse animation (no equivalent progress primitive is used elsewhere in
// this wizard).
//
// Runtime-verified stdin-close idiom (see task-5-report.md for the full
// harness/output): `write(secrets); stdinEnabled = false;` DOES flush the
// write and close the pipe -- a child blocked on reading stdin to EOF
// (`wc -c`) received exactly the written byte count and exited 0, proving
// this is the correct replacement for the GTK original's explicit
// `stdin.write_all(...); stdin.close(None)`.
Item {
    id: root

    // Every page in this wizard follows this convention (see
    // WelcomePage.qml); shell.qml hides both Back and Next while this page
    // is on screen, so neither is ever surfaced here.
    property bool ready: true
    property string nextLabel: "Next"

    property string logText: ""
    property string status: "Installing…"
    property bool failed: false
    property bool _started: false

    function append(text) {
        root.logText += text;
    }

    // Minimal port of Python's shlex.quote(): a token made up only of
    // "safe" characters (shlex's own _find_unsafe charset) is emitted
    // bare; anything else -- spaces, quotes, anything shell-meaningful --
    // is single-quoted, with each embedded single quote closed, escaped,
    // and reopened (' -> '"'"'). Used only to render the dry-run preview
    // line; the real run never goes through a shell at all (Process.command
    // is argv, no shell string of any kind).
    function shQuote(s) {
        if (/^[A-Za-z0-9@%_+=:,.\/-]+$/.test(s) && s.length > 0) return s;
        return "'" + s.replace(/'/g, "'\"'\"'") + "'";
    }

    function quotedCommand() {
        return Cyber.WizState.argv().map(root.shQuote).join(" ");
    }

    // Ported from finish(). code === 0 advances to the done page (next()
    // from "install" lands on "done" -- see WizState.qml's pages list, no
    // skip applies past this point); anything else stays on this page with
    // the failure text appended and a Close control shown.
    function finish(code) {
        if (code === 0) {
            root.status = "Done";
            Cyber.WizState.next();
        } else {
            root.failed = true;
            root.status = "Failed (exit " + code + ")";
            root.append("\nInstallation FAILED with exit code " + code + ".\n"
                        + "The error is in the output above.\n");
        }
    }

    // Ported from start_install(). Dry-run prints the command and treats
    // it as an immediate success, same as the GTK original's `self.finish(0)`
    // right after the DRY RUN append -- no process is ever spawned.
    //
    // The finish(0) call for this path is deferred one event-loop turn via
    // Qt.callLater rather than called inline: this whole function runs
    // inside Component.onCompleted, which itself fires synchronously while
    // the Loader (shell.qml) is still instantiating this page as part of
    // resolving `page`'s own binding (`pages[index]`, see WizState.qml).
    // Calling WizState.next() (which finish() does) from inside that same
    // call stack writes `index` again before the first write has finished
    // propagating -- QML's loop guard then detects this as a "Binding loop
    // detected for property 'page'" and drops the update, leaving the
    // Loader stuck showing this page even though `status` already reads
    // "Done". Qt.callLater runs finish(0) after the current binding
    // evaluation has fully unwound, so the second next() lands cleanly.
    // The real (non-dry-run) path below never hits this: its finish() call
    // comes from installProc's onExited, an async signal well outside the
    // Loader's instantiation call stack.
    function start() {
        if (root._started) return;
        root._started = true;
        root.status = "Installing…";
        if (Cyber.WizState.dryRun) {
            root.append("DRY RUN — would run:\n\n" + root.quotedCommand()
                        + "\n\n(password supplied on stdin, not on the command line)\n");
            Qt.callLater(function () { root.finish(0); });
            return;
        }
        installProc.running = true;
    }

    // Component.onCompleted, not shell.qml -- the Loader (see shell.qml)
    // creates a fresh InstallPage each time "install" becomes the current
    // page, so this fires exactly once per visit, same as the GTK
    // original's on_next() calling start_install() the one time it
    // advances onto this page.
    Component.onCompleted: root.start()

    Process {
        id: installProc
        command: Cyber.WizState.argv()
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => root.append(data + "\n")
        }
        stderr: SplitParser {
            onRead: data => root.append(data + "\n")
        }
        // Line 1 the user's password, line 2 blank (root's, "same as the
        // user's"), line 3 the LUKS passphrase when encrypting -- all over
        // stdin, never argv. stdinEnabled = false immediately after write()
        // flushes the write and closes the pipe (verified at runtime, see
        // the file-level comment above) -- the replacement for the GTK
        // original's explicit stdin.close(None).
        onStarted: {
            write(Cyber.WizState.stdinSecrets());
            stdinEnabled = false;
        }
        onExited: exitCode => root.finish(exitCode)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 12

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Installing CyberOS"
            color: Cyber.Theme.fg
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 8; bold: true }
        }

        Text {
            Layout.fillWidth: true
            text: root.status
            color: root.failed ? Cyber.Theme.alert : Cyber.Theme.muted
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
        }

        Rectangle {
            id: logFrame
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Cyber.Theme.radius / 2
            color: Cyber.Theme.surface
            border.width: 1
            border.color: Cyber.Theme.border

            Flickable {
                id: logFlick
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                contentWidth: width
                contentHeight: logTextItem.height
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: logTextItem
                    width: logFlick.width
                    wrapMode: Text.Wrap
                    text: root.logText
                    color: Cyber.Theme.fg
                    // JetBrainsMono Nerd Font (Theme.fontFamily) is already
                    // a monospace face -- the GTK original's text view
                    // needed an explicit `monospace: true`, this page does
                    // not need a second, different font for the same effect.
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
                    onHeightChanged: logFlick.contentY = Math.max(0, height - logFlick.height)
                }
            }
        }

        Rectangle {
            id: closeBtn
            visible: root.failed
            Layout.alignment: Qt.AlignHCenter
            width: closeLabel.implicitWidth + 40
            height: 36
            radius: height / 2
            color: closeArea.containsMouse ? Cyber.Theme.accent2 : Cyber.Theme.accent

            Text {
                id: closeLabel
                anchors.centerIn: parent
                text: "Close"
                color: Cyber.Theme.bg
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize; bold: true }
            }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Qt.quit()
            }
        }
    }
}
