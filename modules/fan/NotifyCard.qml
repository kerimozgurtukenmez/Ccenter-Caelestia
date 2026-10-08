import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// Bildirimler: kritik sıcaklık, servis durdu, fan komutu başarısız, maksimum fan bitti, kısayolla profil değişimi
Card {
    title: "Bildirimler"

    ToggleRow {
        icon: "notifications"
        label: "Bildirimler"
        sub: "Kritik sıcaklık, NBFC servisi durdu, fan hızı ayarlanamadı, maksimum fan bitti"
        controlled: true
        checked: Notify.enabled
        onToggled: v => Settings.setNotify("enabled", v)
    }
    ToggleRow {
        icon: "tune"
        label: "Profil değişince bildir"
        sub: "Terminalden ya da klavye kısayolundan profil değiştirildiğinde"
        controlled: true
        checked: Notify.profiles
        enabled: Notify.enabled
        opacity: enabled ? 1 : 0.4
        onToggled: v => Settings.setNotify("profile", v)
    }
    Btn {
        Layout.fillWidth: true
        icon: "send"
        text: "Deneme bildirimi gönder"
        enabled: Notify.enabled
        opacity: enabled ? 1 : 0.4
        onClicked: Notify.send("Ccenter", "Bildirimler çalışıyor.", "normal", "dialog-information")
    }
}
