import QtQuick
import ".." as Cyber

// Hint.qml -- shared hint/status label, the QML replacement for the GTK
// wizard's dim-label / "error" css-class label pattern
// (mode_hint/custom_hint/account_hint/luks_hint in cyberos-install-gui).
// Task 4's account/options/custom pages reuse this for validation messages.
//
//   Hint { text: "..." }               // dim informational text
//   Hint { text: "..."; error: true }  // Theme.alert-coloured, for a
//                                      // validation problem
//
// Collapses out of the layout when `text` is empty, same as the GTK labels
// holding "" produced no visible line -- `visible: false` is enough on its
// own (Column/Row/Grid/Flow skip invisible children entirely), so height
// is left as Text's own default (bound to implicitHeight); an explicit
// `height: visible ? implicitHeight : 0` here previously produced a real
// binding loop ("Binding loop detected for property height", caught during
// this task's smoke test) since Text.height already defaults to
// implicitHeight without any help.
Text {
    id: root

    property bool error: false

    wrapMode: Text.WordWrap
    color: root.error ? Cyber.Theme.alert : Cyber.Theme.muted
    font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 1 }
    visible: text.length > 0
}
