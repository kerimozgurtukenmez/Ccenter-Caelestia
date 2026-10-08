import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// Arka plan çalışması: pencere kapanınca uygulama sürer; oturum açılınca başlatma (systemd kullanıcı servisi)
Card {
    title: "Arka plan"

    ToggleRow {
        icon: "login"
        label: "Oturum açılınca arka planda başlat"
        sub: Autostart.installed ? "Pencere açılmadan başlar, fan ayarların hemen uygulanır"
                                 : "Önce kurulum gerekli: sudo make install"
        controlled: true
        checked: Autostart.enabled
        enabled: Autostart.installed && !Autostart.busy
        opacity: enabled ? 1 : 0.5
        onToggled: v => Autostart.setEnabled(v)
    }
    ToggleRow {
        icon: "dock_to_left"
        label: "Sistem tepsisinde göster"
        sub: "Barda ikon: tıkla aç/gizle, üzerine gel: profiller, maksimum fan, kapat"
        controlled: true
        checked: Tray.enabled
        onToggled: v => Settings.setUi("tray", v)
    }
    StyledText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Pencereyi kapatınca uygulama arka planda çalışmaya devam eder. Tekrar açmak için uygulama menüsünden ya da terminalden: ccenter"
        color: Colours.fgDim
        font.pixelSize: 11
    }
    StyledText {
        visible: Autostart.message !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: Autostart.message
        color: Colours.error
        font.pixelSize: 11
    }
    Btn {
        Layout.fillWidth: true
        icon: "power_settings_new"
        text: "Tamamen kapat (fanlar NBFC'ye döner)"
        onClicked: Nbfc.releaseAndQuit()
    }
}
