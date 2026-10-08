pragma Singleton
import Quickshell
import QtQuick
import qs.utils

// Oturum açılınca arka planda başlatma: systemd kullanıcı servisi (dist/ccenter.service).
// Sadece kullanıcı anahtarı değiştirince systemctl çalışır; açılışta yalnızca durum okunur.
Singleton {
    id: root
    readonly property string unit: "ccenter.service"
    readonly property string unitFile: Quickshell.shellPath("dist/ccenter.service")
    property bool enabled: false
    property bool busy: false
    property string message: ""

    function refresh() {
        cmd.go(["systemctl", "--user", "is-enabled", unit], (code, out) => { root.enabled = out.trim() === "enabled" })
    }
    function setEnabled(v) {
        busy = true
        message = ""
        // enable: dosyayı ~/.config/systemd/user altına bağlar (kopyalamaz); disable: bağlantıları kaldırır
        const args = v ? ["systemctl", "--user", "enable", unitFile] : ["systemctl", "--user", "disable", unit]
        cmd.go(args, (code, out, err) => {
            root.busy = false
            if (code !== 0) root.message = "Başarısız: " + (err || out).trim().split("\n")[0]
            root.refresh()
        })
    }

    Cmd { id: cmd }
    Component.onCompleted: refresh()
}
