pragma Singleton
import Quickshell
import QtQuick
import qs.utils

// Oturum açılınca arka planda başlatma: make install ile kurulan systemd kullanıcı servisi (ccenter.service).
// Kurulum yoksa (geliştirme kopyası) anahtar kapalı kalır. Sadece kullanıcı anahtarı değiştirince systemctl çalışır.
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
            if (code !== 0) root.message = "Başarısız: " + (err || out).trim().split("\n")[0]
            root.refresh()
        })
    }

    Cmd { id: cmd }
    Component.onCompleted: refresh()
}
