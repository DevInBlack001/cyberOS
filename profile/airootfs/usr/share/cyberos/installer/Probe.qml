pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System probes for the disk/mode/options pages, ported from the GTK
// wizard's live_medium(), list_disks(), free_space_gib(), partitions() and
// timezones() (cyberos-install-gui). Read-only inspection only -- no disk
// work happens here, same rule as WizState.qml and shell.qml.
//
// Process is always async, so every probe below is a callback chain rather
// than a return value. live_medium must resolve before list_disks runs (the
// disk filter needs to know which device to exclude), so that chain is
// kicked off first and disks only queried from its completion handler.
//
// Spawn-failure note (verified against this Quickshell build's actual
// behaviour, not assumed): if the binary itself is missing, Quickshell's
// Process NEVER emits `exited` -- QProcess::FailedToStart is handled
// internally (a qWarning, nothing else) and only `runningChanged` fires,
// going straight to false, with neither `started` nor `exited` in between.
// `onErrorOccurred` looks like a signal handler in the qmltypes dump but is
// a plain Method (an internal slot wired to the wrapped QProcess, not a
// QML-visible signal) -- declaring `onErrorOccurred:` in QML was confirmed
// to fail to load ("Cannot assign to non-existent property"). So every
// Process below is resolved from a shared handler function reachable from
// both `onExited` (real result) and `onRunningChanged` (synthetic
// exitCode -1, empty text, fired only when running drops to false without
// `exited` having resolved it first) -- the only combination this build
// actually emits on a failed spawn.
Singleton {
    id: root

    // ------------------------------------------------------------- exclude
    // zram and loop devices report TYPE=disk to lsblk but are not install
    // targets: zram0 is compressed RAM, and offering it would let someone
    // "install" into memory. Ruled out by name, since there is no type that
    // separates them. Ported verbatim from NOT_A_TARGET.
    readonly property var _notATarget: /^\/dev\/(zram|loop|ram|sr|fd)\d/

    // ------------------------------------------------------------- results
    property string liveMedium: ""
    property var disks: []
    property var timezones: []
    readonly property var _tzFallback: ["UTC", "Africa/Accra"]

    property bool _liveMediumDone: false
    property bool _disksDone: false
    // True once liveMedium then disks have resolved (including via the
    // spawn-failure path below, so this can never hang). Timezones probes
    // independently in parallel and is NOT covered by this flag -- it can
    // still be the initial `[]` for a moment after `ready` flips true, so
    // consumers of `timezones` must tolerate a briefly-empty list rather
    // than gating on `ready`.
    readonly property bool ready: _liveMediumDone && _disksDone

    Component.onCompleted: {
        findmntProc.running = true;
        tzProc.running = true;
    }

    // --------------------------------------------------- python split(None, n)
    // Mirrors str.split(None, n - 1): split on runs of whitespace, at most
    // n elements, the last element keeps everything remaining verbatim
    // (callers that need it stripped, e.g. the disk MODEL column, call
    // .trim() themselves -- same as the explicit `.strip()` in the GTK code).
    function _pySplit(line, n) {
        var s = line.replace(/^\s+/, "");
        var out = [];
        while (out.length < n - 1) {
            var m = s.match(/^(\S+)\s+([\s\S]*)$/);
            if (!m) break;
            out.push(m[1]);
            s = m[2].replace(/^\s+/, "");
        }
        if (s.length > 0) out.push(s);
        return out;
    }

    // Runs one command, hands (exitCode, stdout text) to the callback, then
    // destroys the Process. Used for the per-disk probes (freeSpaceGib,
    // partitions) that may be invoked repeatedly with different arguments,
    // where a single static Process instance could not serve overlapping
    // calls safely. Resolves through onExited on a normal run, or through
    // onRunningChanged with a synthetic (-1, "") on a failed spawn -- see
    // the file-level spawn-failure note.
    Component {
        id: _procComponent
        Process {
            id: dynProc
            property var cb: null
            property bool _resolved: false
            stdout: StdioCollector { id: out }
            onExited: exitCode => {
                dynProc._resolved = true;
                var text = out.text;
                var fn = cb;
                destroy();
                if (fn) fn(exitCode, text);
            }
            onRunningChanged: {
                if (dynProc.running || dynProc._resolved) return;
                dynProc._resolved = true;
                var fn = cb;
                destroy();
                if (fn) fn(-1, "");
            }
        }
    }

    function _run(cmd, cb) {
        var obj = _procComponent.createObject(root, { command: cmd, cb: cb });
        obj.running = true;
    }

    // ------------------------------------------------------- live medium
    // The disk the live session booted from -- never offered as an install
    // target. Ported from live_medium(). Neither subprocess call in the GTK
    // original checked its return code (check=False); only stdout text
    // mattered, so a failed spawn (empty stdout) naturally falls through to
    // the same "" / fallback-to-source paths a genuinely empty answer took
    // -- true whether the empty text comes from a real empty stdout or the
    // synthetic "" a failed spawn resolves with.
    property bool _findmntResolved: false

    function _onFindmntDone(text) {
        var src = text.trim();
        if (!src) {
            root.liveMedium = "";
            root._liveMediumDone = true;
            disksProc.running = true;
            return;
        }
        src = src.split("[")[0];
        pknameProc.diskSrc = src;
        pknameProc.command = ["lsblk", "-no", "PKNAME", src];
        pknameProc.running = true;
    }

    Process {
        id: findmntProc
        command: ["findmnt", "-no", "SOURCE", "/run/archiso/bootmnt"]
        stdout: StdioCollector { id: findmntOut }
        onExited: {
            root._findmntResolved = true;
            root._onFindmntDone(findmntOut.text);
        }
        onRunningChanged: {
            if (running || root._findmntResolved) return;
            root._findmntResolved = true;
            root._onFindmntDone("");
        }
    }

    function _onPknameDone(text) {
        var lines = text.trim().split("\n").filter(function (l) { return l.length > 0; });
        root.liveMedium = (lines.length > 0 && lines[0]) ? ("/dev/" + lines[0]) : pknameProc.diskSrc;
        root._liveMediumDone = true;
        disksProc.running = true;
    }

    Process {
        id: pknameProc
        property string diskSrc: ""
        property bool _resolved: false
        stdout: StdioCollector { id: pknameOut }
        onExited: {
            pknameProc._resolved = true;
            root._onPknameDone(pknameOut.text);
        }
        onRunningChanged: {
            if (running || pknameProc._resolved) return;
            pknameProc._resolved = true;
            root._onPknameDone("");
        }
    }

    // ------------------------------------------------------------- disks
    // Whole disks only -- no partitions, no zram/loop, not the live medium.
    // Ported from list_disks(); labels formatted exactly as page_disk()
    // built them for the ComboRow. A failed spawn resolves with empty
    // stdout, which the parse loop below naturally turns into an empty
    // `disks` list (no lines match), same as it would for a real empty
    // lsblk answer -- ready still flips true.
    property bool _disksResolved: false

    function _onDisksDone(text) {
        var lines = text.split("\n");
        var result = [];
        for (var i = 0; i < lines.length; i++) {
            var f = root._pySplit(lines[i], 4);
            if (f.length < 3 || f[2] !== "disk") continue;
            var name = f[0], size = f[1];
            if (root._notATarget.test(name) || name === root.liveMedium) continue;
            var model = f.length > 3 ? f[3].trim() : "";
            var label = name + "  (" + size + ")" + (model ? "  " + model.slice(0, 22) : "");
            result.push({ name: name, size: size, model: model, label: label });
        }
        root.disks = result;
        root._disksDone = true;
    }

    Process {
        id: disksProc
        command: ["lsblk", "-dnpo", "NAME,SIZE,TYPE,MODEL"]
        stdout: StdioCollector { id: disksOut }
        onExited: {
            root._disksResolved = true;
            root._onDisksDone(disksOut.text);
        }
        onRunningChanged: {
            if (running || root._disksResolved) return;
            root._disksResolved = true;
            root._onDisksDone("");
        }
    }

    // Mirrors Python's int(text): the whole (already-stripped) string must
    // be an optionally-signed run of digits, or it is not a number --
    // unlike parseInt(), which would happily accept "512garbage" as 512.
    function _pyInt(text) {
        var t = text.trim();
        return /^[+-]?\d+$/.test(t) ? parseInt(t, 10) : NaN;
    }

    // -------------------------------------------------------- free space
    // Size of the largest unallocated block, as the installer measures it.
    // Ported from free_space_gib(): the Python original ran both sgdisk
    // calls with check=True inside a try/except that caught OSError,
    // ValueError and CalledProcessError alike and returned 0 -- so here
    // both a non-zero exit and a non-numeric result are treated as failure.
    // _run()'s synthetic (-1, "") on a failed spawn falls into the same
    // "non-zero exit" branch, so a missing sgdisk resolves to 0 rather than
    // hanging -- exactly what the Python except clause did for a missing
    // binary (FileNotFoundError is an OSError).
    function freeSpaceGib(disk, callback) {
        root._run(["sgdisk", "-F", disk], function (code1, text1) {
            var first = root._pyInt(text1);
            if (code1 !== 0 || isNaN(first)) { callback(0); return; }
            root._run(["sgdisk", "-E", disk], function (code2, text2) {
                var last = root._pyInt(text2);
                if (code2 !== 0 || isNaN(last)) { callback(0); return; }
                callback(Math.max(0, Math.floor((last - first + 1) * 512 / 1073741824)));
            });
        });
    }

    // -------------------------------------------------------- partitions
    // (dev, size, fstype, ptype, label) for each partition on the disk.
    // Ported from partitions(): the disk's own row (lsblk lists the disk
    // itself first, then its partitions) is dropped, same as the Python
    // splitlines()[1:]. No return-code check, matching check=False -- a
    // failed spawn's synthetic "" resolves to the same empty rows list an
    // empty lsblk answer would, rather than hanging (the GTK original had
    // no failure handling to port here at all: a missing lsblk would have
    // crashed the whole app; resolving gracefully instead is a deliberate
    // departure required by this port's own no-eternal-pending constraint).
    function partitions(disk, callback) {
        root._run(["lsblk", "-pnro", "NAME,SIZE,FSTYPE,PARTTYPENAME", disk], function (code, text) {
            var lines = text.split("\n");
            lines.shift();
            var rows = [];
            for (var i = 0; i < lines.length; i++) {
                var f = root._pySplit(lines[i], 4);
                if (f.length < 2) continue;
                var dev = f[0], size = f[1];
                var fstype = f.length > 2 ? f[2] : "";
                var ptype = f.length > 3 ? f[3] : "";
                var label = dev + "  (" + size + ")" + (fstype ? "  " + fstype : "");
                rows.push({ dev: dev, size: size, fstype: fstype, ptype: ptype, label: label });
            }
            callback(rows);
        });
    }

    // ------------------------------------------------------------ timezones
    // Ported from timezones(): the GTK original wrapped the subprocess call
    // in try/except OSError (raised only if timedatectl itself is missing)
    // and fell back to the pinned list whenever that happened OR the parsed
    // result was empty -- no return-code check either way. A failed spawn's
    // synthetic "" parses to zero zones, which is exactly the condition
    // that already applies the fallback below.
    property bool _tzResolved: false

    function _onTzDone(text) {
        var tokens = text.split(/\s+/).filter(function (t) { return t.length > 0; });
        var zones = tokens.filter(function (t) { return t.indexOf("/") !== -1; });
        root.timezones = zones.length > 0 ? zones : root._tzFallback.slice();
    }

    Process {
        id: tzProc
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector { id: tzOut }
        onExited: {
            root._tzResolved = true;
            root._onTzDone(tzOut.text);
        }
        onRunningChanged: {
            if (running || root._tzResolved) return;
            root._tzResolved = true;
            root._onTzDone("");
        }
    }
}
