import Quickshell.Io
import QtQuick

// Runs a one-off command: go(["cmd", "arg"], (code, stdout, stderr) => { ... })
Process {
    id: p
    property var done: null
    // `running` may not be true right after `running = true`; use this to know whether it is busy
    property bool busy: false
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
        busy = false
        if (cb) cb(code, so.text, se.text)
    }
    function go(cmd, cb) {
        done = cb
        busy = true
        gotExit = false; gotOut = false; gotErr = false; code = -1
        command = cmd
        running = true
    }
}
