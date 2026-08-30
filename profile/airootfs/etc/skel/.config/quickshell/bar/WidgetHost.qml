import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell

// Hosts student drop-in widgets from ~/.config/quickshell/widgets/*.qml on the
// bar. Every *.qml file there is picked up, sorted by filename (the sort a
// student uses to order their own widgets on the bar), and given its own
// Loader. See widgets/README.md for the contract this implements.
RowLayout {
    spacing: 6

    FolderListModel {
        id: widgets
        // See Theme.qml: Quickshell.env() returns "" (not null) for an
        // unset var, so `!== ""` is always true -- check truthiness instead.
        folder: {
            const c = Quickshell.env("XDG_CONFIG_HOME");
            return "file://" + (c ? c : Quickshell.env("HOME") + "/.config") + "/quickshell/widgets";
        }
        nameFilters: ["*.qml"]
        sortField: FolderListModel.Name
        showDirs: false
    }
    Repeater {
        model: widgets
        // A broken student widget must not take the bar down: each entry gets
        // its own Loader, so a QML error in one file only empties that one
        // slot -- the rest of the bar (and the rest of the widgets) survives.
        Loader {
            required property url fileUrl
            source: fileUrl
            asynchronous: true
            onStatusChanged: if (status === Loader.Error)
                console.warn("cyberos widget failed to load:", fileUrl)
        }
    }
}
