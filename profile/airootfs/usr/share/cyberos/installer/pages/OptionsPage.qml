import QtQuick
import QtQuick.Controls
import "."
import ".." as Cyber

// Ported verbatim from the GTK wizard's page_options() (~307-345),
// on_encrypt_toggled() (~347-355) and validate_encryption() (~357-371)
// (cyberos-install-gui). Same hint-visibility call as AccountPage.qml (read
// its header comment first) applied to the LUKS passphrase pair only --
// `touched` starts false, flips true on the first editingFinished from
// either passphrase field, and is reset back to false every time the
// encrypt switch is toggled (mirroring on_encrypt_toggled(), which always
// blanked luks_hint's text on every toggle, on or off) so flipping the
// switch never paints a stale error before the user has typed anything.
// Unlike account_hint/custom_hint (an error-styled label),
// luks_hint used only "dim-label"/"caption" -- Hint.error is left false
// here (its default) to match, `error: true` is set explicitly wherever
// the GTK original really did use the "error" class.
Item {
    id: root

    property bool ready: root._problem().length === 0
    property string nextLabel: "Next"
    // Starts false so a fresh visit's blank/default fields don't paint an
    // error before the user has touched anything, and flips true on the
    // first editingFinished from either passphrase field. The Loader
    // destroys and recreates this Item on every visit (see shell.qml),
    // which would otherwise reset `touched` back to false even when
    // WizState.encrypt/luksPass already hold a real answer from before --
    // hiding the "do not match" hint behind a dead Next button with no
    // visible reason. Component.onCompleted below re-seeds `touched` to
    // true in exactly that case (encrypt on and a non-empty luksPass
    // already set), so the hint reappears immediately instead of only
    // after the user retypes something. A future StackView-style cache
    // that kept pages alive across navigation would need to drop both the
    // reset and this seeding logic (touched would simply never reset).
    property bool touched: false

    // Confirm-passphrase has no WizState home, same reasoning as
    // AccountPage.qml's _pw2 -- the GTK's e_luks2 lived only on the page.
    property string _luksPass2: ""

    // Ported from validate_encryption().
    function _problem() {
        if (!Cyber.WizState.encrypt) return "";
        var pw = Cyber.WizState.luksPass, pw2 = root._luksPass2;
        if (!pw)
            return "An empty passphrase would produce a disk nobody can open.";
        if (pw !== pw2)
            return "The passphrases do not match.";
        if (pw.length < 8)
            return "Use at least 8 characters; this is the only thing protecting the disk.";
        return "";
    }

    // Ported from refresh_partitions()-style "pick a default once probed
    // data arrives" (same pattern DiskPage.qml uses for `disk`).
    // Probe.timezones can still be the initial `[]` for a moment after
    // Probe.ready flips true (see Probe.qml's file-level comment), so both
    // Component.onCompleted and a Connections{ onTimezonesChanged } hook
    // below are needed -- one for the case Probe already resolved by the
    // time this page loads, one for the case it resolves later while the
    // page is already on screen.
    //
    // Same Loader-recreation hazard DiskPage.qml's _pickDefault() has:
    // `tzCombo` resets to index 0 on every re-visit even though
    // WizState.tz survives untouched, so a re-entered page must restore
    // the combo to WizState.tz's current index first (via the shared
    // WizState.indexOfValue() helper -- see its comment for why it lives
    // there) and only fall back to picking a fresh default when there is
    // nothing to restore, or the zone no longer appears in the probed list.
    function _pickDefaultTz() {
        var zones = Cyber.Probe.timezones;
        if (zones.length === 0) return;
        if (Cyber.WizState.tz) {
            var idx = Cyber.WizState.indexOfValue(zones, Cyber.WizState.tz);
            if (idx !== -1) {
                tzCombo.currentIndex = idx;
                return;
            }
        }
        // Ported from `"Africa/Accra" if "Africa/Accra" in zones else
        // "UTC"`. The GTK original then did `zones.index(default_tz)`
        // unconditionally, which would raise if neither zone were present
        // (unreachable in practice -- Africa/Accra ships in every tzdata --
        // but not provably so from this code alone); falling back to index
        // 0 instead of crashing is a deliberate, low-risk departure for
        // that edge case only, matching the "never hang/crash on a bad
        // probe result" rule Probe.qml itself already established.
        var def = zones.indexOf("Africa/Accra") !== -1 ? "Africa/Accra"
                : zones.indexOf("UTC") !== -1 ? "UTC" : zones[0];
        Cyber.WizState.tz = def;
        tzCombo.currentIndex = zones.indexOf(def);
    }

    Component.onCompleted: {
        root._pickDefaultTz();
        fsCombo.currentIndex = ["ext4", "btrfs"].indexOf(Cyber.WizState.fs);
        // I2: seed `touched` so a re-entered page with an already-set LUKS
        // passphrase pair shows its hint immediately rather than hiding
        // behind a freshly-reset `touched` -- see the property's comment.
        root.touched = Cyber.WizState.encrypt && Cyber.WizState.luksPass !== "";
    }
    Connections {
        target: Cyber.Probe
        function onTimezonesChanged() { root._pickDefaultTz(); }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Options"
            color: Cyber.Theme.fg
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize + 8; bold: true }
        }

        Field {
            width: parent.width
            label: "Time zone"

            ComboBox {
                id: tzCombo
                width: 260
                height: 34
                enabled: Cyber.Probe.timezones.length > 0
                model: Cyber.Probe.timezones.length > 0
                       ? Cyber.Probe.timezones : ["no timezones found"]
                onActivated: function (index) {
                    if (Cyber.Probe.timezones.length > 0)
                        Cyber.WizState.tz = Cyber.Probe.timezones[index];
                }

                contentItem: Text {
                    text: tzCombo.displayText
                    color: Cyber.Theme.fg
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                    rightPadding: 24
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
                background: Rectangle {
                    implicitWidth: 260
                    implicitHeight: 34
                    radius: Cyber.Theme.radius / 2
                    color: Cyber.Theme.surface
                    border.width: 1
                    border.color: tzCombo.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                }
                indicator: Text {
                    x: tzCombo.width - width - 10
                    y: (tzCombo.height - height) / 2
                    text: "\uf0d7"
                    color: Cyber.Theme.muted
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
                }
                delegate: ItemDelegate {
                    width: tzCombo.width
                    highlighted: tzCombo.highlightedIndex === index
                    contentItem: Text {
                        text: modelData
                        color: Cyber.Theme.fg
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                    }
                    background: Rectangle {
                        color: highlighted ? Cyber.Theme.sel : Cyber.Theme.surface
                    }
                }
                popup: Popup {
                    y: tzCombo.height + 2
                    width: tzCombo.width
                    implicitHeight: Math.min(contentItem.implicitHeight, 200)
                    padding: 1

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: tzCombo.popup.visible ? tzCombo.delegateModel : null
                        currentIndex: tzCombo.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator {}
                    }
                    background: Rectangle {
                        color: Cyber.Theme.surface
                        border.width: 1
                        border.color: Cyber.Theme.border
                        radius: Cyber.Theme.radius / 2
                    }
                }
            }
        }

        Field {
            width: parent.width
            label: "Filesystem"

            ComboBox {
                id: fsCombo
                width: 260
                height: 34
                model: ["ext4", "btrfs"]
                onActivated: function (index) { Cyber.WizState.fs = ["ext4", "btrfs"][index]; }

                contentItem: Text {
                    text: fsCombo.displayText
                    color: Cyber.Theme.fg
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                    rightPadding: 24
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
                background: Rectangle {
                    implicitWidth: 260
                    implicitHeight: 34
                    radius: Cyber.Theme.radius / 2
                    color: Cyber.Theme.surface
                    border.width: 1
                    border.color: fsCombo.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                }
                indicator: Text {
                    x: fsCombo.width - width - 10
                    y: (fsCombo.height - height) / 2
                    text: "\uf0d7"
                    color: Cyber.Theme.muted
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
                }
                delegate: ItemDelegate {
                    width: fsCombo.width
                    highlighted: fsCombo.highlightedIndex === index
                    contentItem: Text {
                        text: modelData
                        color: Cyber.Theme.fg
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                    }
                    background: Rectangle {
                        color: highlighted ? Cyber.Theme.sel : Cyber.Theme.surface
                    }
                }
                popup: Popup {
                    y: fsCombo.height + 2
                    width: fsCombo.width
                    implicitHeight: Math.min(contentItem.implicitHeight, 200)
                    padding: 1

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: fsCombo.popup.visible ? fsCombo.delegateModel : null
                        currentIndex: fsCombo.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator {}
                    }
                    background: Rectangle {
                        color: Cyber.Theme.surface
                        border.width: 1
                        border.color: Cyber.Theme.border
                        radius: Cyber.Theme.radius / 2
                    }
                }
            }
        }

        Field {
            width: parent.width
            label: "Swap file"
            subtitle: "GiB, 0 for none"

            SpinBox {
                id: swapSpin
                width: 260
                height: 34
                from: 0
                to: 64
                value: Cyber.WizState.swapGib
                editable: true
                onValueModified: Cyber.WizState.swapGib = value

                contentItem: TextInput {
                    text: swapSpin.textFromValue(swapSpin.value, swapSpin.locale)
                    color: Cyber.Theme.fg
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    readOnly: !swapSpin.editable
                    validator: swapSpin.validator
                    inputMethodHints: Qt.ImhDigitsOnly
                    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                }
                up.indicator: Rectangle {
                    x: swapSpin.width - width
                    width: 34
                    height: swapSpin.height
                    color: swapSpin.up.pressed ? Cyber.Theme.sel : Cyber.Theme.surface
                    border.width: 1
                    border.color: Cyber.Theme.border
                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Cyber.Theme.fg
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                    }
                }
                down.indicator: Rectangle {
                    x: 0
                    width: 34
                    height: swapSpin.height
                    color: swapSpin.down.pressed ? Cyber.Theme.sel : Cyber.Theme.surface
                    border.width: 1
                    border.color: Cyber.Theme.border
                    Text {
                        anchors.centerIn: parent
                        text: "-"
                        color: Cyber.Theme.fg
                        font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                    }
                }
                background: Rectangle {
                    radius: Cyber.Theme.radius / 2
                    color: Cyber.Theme.surface
                    border.width: 1
                    border.color: swapSpin.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                }
            }
        }

        Field {
            width: parent.width
            label: "Encrypt this disk"
            subtitle: "LUKS2. You will be asked for this passphrase at every boot."

            Rectangle {
                id: encTrack
                width: 44
                height: 24
                radius: 12
                color: Cyber.WizState.encrypt ? Cyber.Theme.accent : Cyber.Theme.border

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: Cyber.Theme.surface
                    anchors.verticalCenter: parent.verticalCenter
                    x: Cyber.WizState.encrypt ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Cyber.WizState.encrypt = !Cyber.WizState.encrypt;
                        root.touched = false;
                        if (!Cyber.WizState.encrypt) {
                            Cyber.WizState.luksPass = "";
                            root._luksPass2 = "";
                        }
                    }
                }
            }
        }

        Field {
            width: parent.width
            label: "Encryption passphrase"

            TextField {
                id: luksField
                width: 260
                height: 34
                enabled: Cyber.WizState.encrypt
                opacity: enabled ? 1 : 0.5
                text: Cyber.WizState.luksPass
                echoMode: TextInput.Password
                color: Cyber.Theme.fg
                selectByMouse: true
                leftPadding: 10
                rightPadding: 10
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                onTextChanged: Cyber.WizState.luksPass = text
                onEditingFinished: root.touched = true
                background: Rectangle {
                    radius: Cyber.Theme.radius / 2
                    color: Cyber.Theme.surface
                    border.width: 1
                    border.color: luksField.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                }
            }
        }

        Field {
            width: parent.width
            label: "Confirm passphrase"

            TextField {
                id: luks2Field
                width: 260
                height: 34
                enabled: Cyber.WizState.encrypt
                opacity: enabled ? 1 : 0.5
                text: root._luksPass2
                echoMode: TextInput.Password
                color: Cyber.Theme.fg
                selectByMouse: true
                leftPadding: 10
                rightPadding: 10
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
                onTextChanged: root._luksPass2 = text
                onEditingFinished: root.touched = true
                background: Rectangle {
                    radius: Cyber.Theme.radius / 2
                    color: Cyber.Theme.surface
                    border.width: 1
                    border.color: luks2Field.activeFocus ? Cyber.Theme.accent : Cyber.Theme.border
                }
            }
        }

        Hint {
            width: parent.width
            text: root.touched ? root._problem() : ""
        }
    }
}
