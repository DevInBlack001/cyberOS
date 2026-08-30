import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
    id: sysStats
    spacing: 2

    property real memPct: 0
    property real cpuPct: 0
    property real prevIdle: 0
    property real prevTotal: 0

    Process {
        id: statProc
        command: ["sh", "-c", "grep -m1 cpu /proc/stat; grep -E 'MemTotal|MemAvailable' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const cpuFields = lines[0].trim().split(/\s+/).slice(1).map(Number);
                const idle = cpuFields[3] + (cpuFields[4] ?? 0);
                const total = cpuFields.reduce((a, b) => a + b, 0);
                const dIdle = idle - sysStats.prevIdle;
                const dTotal = total - sysStats.prevTotal;
                if (dTotal > 0) sysStats.cpuPct = 1 - dIdle / dTotal;
                sysStats.prevIdle = idle;
                sysStats.prevTotal = total;

                let memTotal = 0, memAvail = 0;
                for (const l of lines.slice(1)) {
                    const m = l.match(/(\d+)/);
                    if (l.startsWith("MemTotal")) memTotal = Number(m[1]);
                    else if (l.startsWith("MemAvailable")) memAvail = Number(m[1]);
                }
                if (memTotal > 0) sysStats.memPct = 1 - memAvail / memTotal;
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: statProc.running = true
    }

    BarModule {
        icon: "\uf2db"
        label: Math.round(sysStats.memPct * 100) + "%"
        tooltip: "Memory usage"
        onClicked: Quickshell.execDetached(["foot", "-e", "btop"])
    }
    BarModule {
        icon: "\uf4bc"
        label: Math.round(sysStats.cpuPct * 100) + "%"
        tooltip: "CPU usage"
        onClicked: Quickshell.execDetached(["foot", "-e", "btop"])
    }
}
