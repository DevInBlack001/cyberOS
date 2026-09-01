import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import "../" as Cyber

// Replaces gwenview. A real toplevel window (FloatingWindow), not a layer
// surface, so it tiles and shows up in the window switcher like an app.
// Opened by `qs ipc call images open <path>` -- which is exactly what
// cyberos-images.desktop execs, so mime-opening a picture from anywhere
// (Files, Firefox downloads) lands here.
//
// Arrow keys walk the containing directory. FolderListModel exposes NO
// per-item file-URL role (that lookup returns undefined, and indexOf() then
// throws a TypeError about incompatible C++ arguments) -- so the current
// image's position comes from indexOf() fed a "file://"-prefixed filePath,
// which is verified to return the correct index.
FloatingWindow {
    id: root

    property string path: ""
    readonly property string fileName: root.path.split("/").pop()
    readonly property string dirPath: root.path.substring(0, root.path.lastIndexOf("/"))

    title: root.path === "" ? "Images"
        : root.fileName + "  —  " + img.sourceSize.width + "×" + img.sourceSize.height
    implicitWidth: 900
    implicitHeight: 620
    minimumSize: Qt.size(360, 240)
    color: Cyber.Theme.bg

    FolderListModel {
        id: dir
        folder: root.dirPath === "" ? "" : "file://" + root.dirPath
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.bmp", "*.svg"]
    }

    // Step by +1/-1 through the filtered listing, wrapping at both ends so a
    // student never hits a dead arrow key.
    function step(delta) {
        if (dir.count === 0) return;
        const here = dir.indexOf("file://" + root.path);
        // -1 means the current file did not match nameFilters; start at 0.
        const next = here < 0 ? 0 : (here + delta + dir.count) % dir.count;
        root.path = dir.get(next, "filePath");
    }

    function fit()  { img.scale = 1; pan.x = 0; pan.y = 0; }
    function zoom(factor) { img.scale = Math.max(0.1, Math.min(8, img.scale * factor)); }

    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Right:  root.step(1);  event.accepted = true; break;
            case Qt.Key_Left:   root.step(-1); event.accepted = true; break;
            case Qt.Key_Plus:
            case Qt.Key_Equal:  root.zoom(1.25); event.accepted = true; break;
            case Qt.Key_Minus:  root.zoom(0.8);  event.accepted = true; break;
            case Qt.Key_0:      root.fit(); event.accepted = true; break;
            case Qt.Key_1:      img.scale = 1; event.accepted = true; break;
            case Qt.Key_Escape: root.visible = false; event.accepted = true; break;
            }
        }

        Image {
            id: img
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            source: root.path === "" ? "" : "file://" + root.path
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            // Big photos on a software-rendered VM: cap the decode, keep the
            // smooth filter for the common downscale.
            sourceSize.width: 4096
            smooth: true

            // Anchors beat x/y in Qt Quick, so an anchored item cannot be
            // moved by a drag -- pan through a transform instead.
            transform: Translate { id: pan }
        }

        // Deliberately a sibling of the Image, not a child: a MouseArea
        // inside the transformed subtree receives coordinates that Qt has
        // already adjusted by `pan`, so subtracting pan again in onPressed
        // double-compensates and the drag oscillates instead of tracking.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            property real originX: 0
            property real originY: 0
            onPressed: mouse => { originX = mouse.x - pan.x; originY = mouse.y - pan.y; }
            onPositionChanged: mouse => {
                if (pressed) { pan.x = mouse.x - originX; pan.y = mouse.y - originY; }
            }
            onWheel: wheel => root.zoom(wheel.angleDelta.y > 0 ? 1.15 : 0.87)
            onDoubleClicked: root.fit()
        }

        Text {
            visible: root.path === "" || img.status === Image.Error
            anchors.centerIn: parent
            text: root.path === "" ? "No image" : "Could not load\n" + root.fileName
            horizontalAlignment: Text.AlignHCenter
            color: Cyber.Theme.muted
            font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize }
        }

        Rectangle {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 10 }
            width: hint.implicitWidth + 16
            height: hint.implicitHeight + 8
            radius: Cyber.Theme.radius / 2
            color: Cyber.Theme.surface
            opacity: 0.85
            Text {
                id: hint
                anchors.centerIn: parent
                text: "← → browse · +/- zoom · 0 fit · Esc close"
                color: Cyber.Theme.muted
                font { family: Cyber.Theme.fontFamily; pixelSize: Cyber.Theme.fontSize - 3 }
            }
        }
    }
}
