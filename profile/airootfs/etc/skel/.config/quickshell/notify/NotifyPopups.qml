import QtQuick
import QtQuick.Layouts
import Quickshell
import ".." as Cyber

// Replaces mako's own popup rendering. Instantiated once from shell.qml via
// an always-`active` LazyLoader (see shell.qml's comment) and driven purely
// by two properties set at that instantiation site -- `server` (the
// NotificationServer) and `dnd` -- rather than by bare-referencing shell.qml
// ids from in here. PowerMenu.qml/Launcher.qml solve the analogous problem
// with a `closeRequested` signal wired at the call site; this is the same
// pattern applied to data flowing in instead of a request flowing out.
PanelWindow {
    id: root

    required property var server
    property bool dnd: false

    anchors { top: true; right: true }
    // Clears the 30px bar (Theme.barHeight) plus its own margins/border,
    // with a little breathing room -- matches the bar's own left/right
    // outer margin (5) plus a bit more so the stack doesn't hug the corner.
    margins { top: 40; right: 10 }
    implicitWidth: 340
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"

    // A transient overlay, not a dock: must never reserve screen space.
    // Same belt-and-braces pair as osd/Osd.qml (exclusiveZone alone isn't
    // enough on this qmltypes -- see that file's comment for the verified
    // reasoning); exclusiveZone is spelled out literally for the policy
    // grep in tests/surfaces2.bats and the plan's own wording.
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    // Cap at 20 visible notifications. Critical notifications never auto-expire
    // (NotifyCard.qml), so a local process flooding the session bus with critical
    // urgency could grow this stack without bound. Slice from the end so the
    // newest notifications are the ones shown.
    readonly property var tracked: {
        const all = root.server ? root.server.trackedNotifications.values : [];
        return all.length > 20 ? all.slice(all.length - 20) : all;
    }

    // Hidden entirely -- not just empty -- whenever there is nothing to
    // show or DND is on, so no layer surface is mapped at all in either
    // case (verified live: `hyprctl layers` drops the surface once the
    // last card expires/dismisses, or the instant DND flips on).
    visible: !root.dnd && root.tracked.length > 0

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 8

        // Same ScriptModel/Identity story as launcher/Launcher.qml's grid:
        // Notification objects are stable QObjects owned by the server, so
        // diffing by identity keeps a still-tracked card's delegate (and any
        // running expiry Timer) alive across insertions/removals instead of
        // rebuilding the whole stack whenever one notification is added or
        // removed.
        Repeater {
            model: ScriptModel {
                values: root.tracked
                comparisonMode: ObjectComparison.Identity
            }

            delegate: NotifyCard {
                required property var modelData
                Layout.fillWidth: true
                notification: modelData
            }
        }
    }
}
