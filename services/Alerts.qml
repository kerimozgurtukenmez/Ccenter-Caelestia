pragma Singleton
import Quickshell
import QtQuick

// Olayları izler ve bildirim gönderir. Aynı olay için art arda bildirim gitmez.
Singleton {
    id: root

    // Kritik sıcaklık: güvenlik sınırına ulaşınca bir kez; 5°C soğuyunca yeniden kurulur
    property bool armed: true
    readonly property real hot: {
        const c = Nbfc.temp, g = Sensors.gpu
        return isFinite(g) ? (isFinite(c) ? Math.max(c, g) : g) : c
    }
    onHotChanged: {
        if (!isFinite(hot)) return
        if (armed && hot >= Nbfc.safety) {
            armed = false
            const who = isFinite(Sensors.gpu) && Sensors.gpu >= Nbfc.temp ? "GPU" : "CPU"
            const owned = Object.keys(Nbfc.targets).length > 0
            Notify.send("Kritik sıcaklık: " + Math.round(hot) + "°C (" + who + ")",
                        owned ? "Güvenlik sınırı (" + Nbfc.safety + "°C) aşıldı; Ccenter'ın kontrol ettiği fanlar %100'e alındı."
                              : "Güvenlik sınırı (" + Nbfc.safety + "°C) aşıldı; fanlar NBFC kontrolünde.",
                        "critical", "dialog-warning")
        } else if (!armed && hot < Nbfc.safety - 5) {
            armed = true
        }
    }

    property double lastFail: 0
    Connections {
        target: Nbfc
        function onServiceLost() {
            Notify.send("NBFC servisi durdu", "Fan kontrolü yapılamıyor. Ccenter'dan ya da `sudo nbfc start` ile yeniden başlatabilirsin.",
                        "critical", "dialog-error")
        }
        function onCommandFailed(msg) {
            const now = Date.now()
            if (now - root.lastFail < 300000) return          // en fazla 5 dakikada bir
            root.lastFail = now
            Notify.send("Fan hızı ayarlanamadı", msg, "critical", "dialog-error")
        }
        function onBoostEnded() {
            Notify.send("Maksimum fan sona erdi", "Fanlar önceki ayarlarına döndü.", "low", "dialog-information")
        }
    }
}
