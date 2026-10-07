import Quickshell.Io
import QtQuick

// Tek seferlik komut çalıştırır: go(["cmd", "arg"], (code, stdout, stderr) => { ... })
Process {
    id: p
    property var done: null
    property int code: -1
    property bool gotExit: false
    property bool gotOut: false
    property bool gotErr: false

    stdout: StdioCollector { id: so; onStreamFinished: { p.gotOut = true; p.fin() } }
    stderr: StdioCollector { id: se; onStreamFinished: { p.gotErr = true; p.fin() } }
    onExited: (exitCode, exitStatus) => { p.code = exitCode; p.gotExit = true; p.fin() }

    function fin() {
        if (!gotExit || !gotOut || !gotErr) return
        const cb = done
        done = null
        if (cb) cb(code, so.text, se.text)
    }
    function go(cmd, cb) {
        done = cb
        gotExit = false; gotOut = false; gotErr = false; code = -1
        command = cmd
        running = true
    }
}
