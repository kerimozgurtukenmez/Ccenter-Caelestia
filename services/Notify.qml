pragma Singleton
import Quickshell
import QtQuick

// Masaüstü bildirimi (notify-send -> bildirim sunucusu; Caelestia'da Caelestia'nın bildirimleri)
Singleton {
    id: root
    readonly property bool enabled: Settings.notifyOn("enabled")       // ana anahtar
    readonly property bool profiles: Settings.notifyOn("profile")      // kısayolla profil değişince

    // urgency: "low" | "normal" | "critical"
    function send(title, body, urgency, icon) {
        if (!enabled) return
        Quickshell.execDetached(["notify-send", "-a", "Ccenter", "-u", urgency || "normal",
                                 "-i", icon || "dialog-information", title, body || ""])
    }
}
