pragma Singleton
import Quickshell
import QtQuick
import qs.utils

// Start in the background on login: the systemd user service ccenter.service installed by install.sh / make install.
// Without an installation (development copy) the toggle stays disabled. systemctl only runs when the user flips the toggle.
Singleton {
    id: root
    readonly property string unit: "ccenter.service"
    property bool installed: false
    property bool enabled: false
    property bool busy: false
    property string message: ""

    function refresh() {
        cmd.go(["systemctl", "--user", "show", "-p", "LoadState,UnitFileState", unit], (code, out) => {
            root.installed = /LoadState=loaded/.test(out)
            root.enabled = /UnitFileState=enabled/.test(out)
        })
    }
    function setEnabled(v) {
        if (!installed) return
        busy = true
        message = ""
        cmd.go(["systemctl", "--user", v ? "enable" : "disable", unit], (code, out, err) => {
            root.busy = false
            if (code !== 0) root.message = I18n.t("Failed: %1").arg((err || out).trim().split("\n")[0])
            root.refresh()
        })
    }

    Cmd { id: cmd }
    Component.onCompleted: refresh()
}
