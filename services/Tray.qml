pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Sistem tepsisi ikonu: scripts/tray.py'yi alt süreç olarak çalıştırır (Caelestia barında görünür).
// Durum JSON satırı olarak stdin'e yazılır; tray.py tıklamaları stdout'a komut olarak yazar.
Singleton {
    id: root
    readonly property bool enabled: Settings.uiOn("tray")
    // Tepsi ikonu: uygulama ikonu (yüklenemezse tema ikonu "ccenter")
    readonly property string iconFile: Quickshell.shellPath("assets/ccenter.svg")

    // shell.qml bağlar
    property bool windowVisible: true
    property var profiles: []
    property string active: ""
    property bool boost: false
    property string tooltip: "Ccenter"

    signal toggleRequested()
    signal profileRequested(string name)

    readonly property string stateLine: JSON.stringify({ profiles: profiles, active: active, boost: boost,
                                                         visible: windowVisible, tooltip: tooltip })
    onStateLineChanged: push()
    function push() { if (proc.running) proc.write(stateLine + "\n") }

    Process {
        id: proc
        running: root.enabled
        command: ["python3", Quickshell.shellPath("scripts/tray.py"), root.iconFile]
        stdinEnabled: true
        onStarted: root.push()
        stdout: SplitParser {
            onRead: line => {
                const sp = line.indexOf(" ")
                const cmd = sp < 0 ? line : line.slice(0, sp)
                const arg = sp < 0 ? "" : line.slice(sp + 1)
                if (cmd === "toggle") root.toggleRequested()
                else if (cmd === "profile") root.profileRequested(arg)
                else if (cmd === "boost") Nbfc.setBoost(parseInt(arg) || 0)
                else if (cmd === "quit") Nbfc.releaseAndQuit()
            }
        }
        stderr: SplitParser { onRead: line => console.warn("[ccenter] tepsi: " + line) }
    }
}
