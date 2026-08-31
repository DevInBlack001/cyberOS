import QtQuick
import QtQuick.Controls
import "."
import ".." as Cyber

// Ported verbatim from the GTK wizard's page_account() (~293-305) and
// validate_account() (~465-479) (cyberos-install-gui). The GTK original
// only validated on Next-click, painting account_hint then; Next here is a
// real button gated by `ready` (continuous, computed live below) rather
// than a click-then-check step, and it is simply disabled while invalid --
// there is no "clicked while invalid" event left to hang a "just attempted"
// hint reveal off of. The least-invasive faithful stand-in: `touched`
// starts false so the four blank/default fields don't paint an error before
// the user has done anything, and flips true the first time any field's
// `editingFinished` fires (Enter, or focus leaving it -- which a Tab key
// naturally triggers) -- i.e. the hint appears once the user has finished
// with at least one field, same spirit as "the user tried to move on".
Item {
    id: root

    property bool ready: root._problem().length === 0
    property string nextLabel: "Next"
    // Resets to false on every fresh visit to this page only because the
    // Loader destroys and recreates this Item each time (see shell.qml) --
    // a future StackView-style cache that kept pages alive across
    // navigation would need an explicit reset here instead.
    property bool touched: false

    // Confirm-password has no WizState home -- see WizState.qml's account
    // section comment. Page-local only, same as the GTK's e_pass2.
    property string _pw2: ""

    function _problem() {
        var user = Cyber.WizState.user.trim();
        if (!/^[a-z_][a-z0-9_-]*$/.test(user))
            return "Username must be lowercase letters, digits, - or _";
        if (!Cyber.WizState.password)
            return "Password cannot be empty";
        if (Cyber.WizState.password !== root._pw2)
            return "Passwords do not match";
        if (!Cyber.WizState.host.trim())
            return "Computer name cannot be empty";
        return "";
    }

    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Create your account"
            color: Cyber.Theme.fg
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 8; bold: true }
        }

        Field {
            width: parent.width
            label: "Username"

            TextField {
                id: userField
                width: 260
                height: 34
                text: Cyber.WizState.user
                color: Cyber.Theme.fg
                selectByMouse: true
                leftPadding: 10
                rightPadding: 10
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                onTextChanged: Cyber.WizState.user = text
                onEditingFinished: root.touched = true
                background: Rectangle {
                    radius: Cyber.Theme.radius / 2
                    color: Cyber.Theme.surface
                    border.width: 1
                    border.color: userField.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                }
            }
        }

        Field {
            width: parent.width
            label: "Computer name"

            TextField {
                id: hostField
                width: 260
                height: 34
                text: Cyber.WizState.host
                color: Cyber.Theme.fg
                selectByMouse: true
                leftPadding: 10
                rightPadding: 10
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                onTextChanged: Cyber.WizState.host = text
                onEditingFinished: root.touched = true
                background: Rectangle {
                    radius: Cyber.Theme.radius / 2
                    color: Cyber.Theme.surface
                    border.width: 1
                    border.color: hostField.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                }
            }
        }

        Field {
            width: parent.width
            label: "Password"

            TextField {
                id: passField
                width: 260
                height: 34
                text: Cyber.WizState.password
                echoMode: TextInput.Password
                color: Cyber.Theme.fg
                selectByMouse: true
                leftPadding: 10
                rightPadding: 10
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                onTextChanged: Cyber.WizState.password = text
                onEditingFinished: root.touched = true
                background: Rectangle {
                    radius: Cyber.Theme.radius / 2
                    color: Cyber.Theme.surface
                    border.width: 1
                    border.color: passField.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                }
            }
        }

        Field {
            width: parent.width
            label: "Confirm password"

            TextField {
                id: pass2Field
                width: 260
                height: 34
                text: root._pw2
                echoMode: TextInput.Password
                color: Cyber.Theme.fg
                selectByMouse: true
                leftPadding: 10
                rightPadding: 10
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                onTextChanged: root._pw2 = text
                onEditingFinished: root.touched = true
                background: Rectangle {
                    radius: Cyber.Theme.radius / 2
                    color: Cyber.Theme.surface
                    border.width: 1
                    border.color: pass2Field.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                }
            }
        }

        Hint {
            width: parent.width
            error: true
            text: root.touched ? root._problem() : ""
        }
    }
}
