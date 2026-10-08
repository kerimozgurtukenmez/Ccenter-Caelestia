import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

Card {
    id: svc
    title: "NBFC servisi"

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Rectangle { implicitWidth: 10; implicitHeight: 10; radius: 5; color: Nbfc.running ? Colours.success : Colours.outline }
        StyledText {
            text: Nbfc.running ? (Nbfc.readOnly ? "Çalışıyor (salt-okunur)" : "Çalışıyor") : "Durduruldu"
            color: Colours.fg
            font { pixelSize: 15; bold: true }
        }
        Item { Layout.fillWidth: true }
        StyledText { visible: Nbfc.running && isFinite(Nbfc.temp); text: "thermostat"; color: Colours.primary; font { family: Colours.iconFont; pixelSize: 20 } }
        StyledText { visible: Nbfc.running && isFinite(Nbfc.temp); text: Math.round(Nbfc.temp) + "°C"; color: Colours.fg; font { pixelSize: 15; bold: true } }
    }
    StyledText {
        Layout.fillWidth: true
        visible: Nbfc.message !== ""
        text: Nbfc.message
        wrapMode: Text.WordWrap
        color: Nbfc.messageError ? Colours.error : Colours.fgDim
        font.pixelSize: 12
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Btn {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            filled: !Nbfc.running
            icon: Nbfc.running ? "stop" : "play_arrow"
            text: Nbfc.running ? "Durdur" : "Başlat"
            onClicked: Nbfc.running ? Nbfc.stopService() : Nbfc.startService()
        }
        Btn {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            icon: "restart_alt"; text: "Yeniden başlat"
            enabled: Nbfc.running
            opacity: enabled ? 1 : 0.4
            onClicked: Nbfc.restartService(Nbfc.readOnly)
        }
    }
    ToggleRow {
        icon: "rocket_launch"; label: "Açılışta başlat"; sub: "Servis sistem açılırken kendiliğinden çalışır"
        controlled: true
        checked: Nbfc.bootEnabled
        onToggled: v => Nbfc.setBoot(v)
    }
    ToggleRow {
        icon: "visibility"; label: "Salt-okunur mod"; sub: "Sadece okur, fan hızı yazmaz. Yeni config'i güvenle denemek için"
        controlled: true
        checked: Nbfc.readOnly
        onToggled: v => Nbfc.setReadOnly(v)
    }
    SliderRow {
        label: "Güvenlik sınırı (Sabit/Eğri modunda üstünde %100)"
        value: (Nbfc.safety - 70) / 30
        readout: Math.round(Nbfc.safety) + "°C"
        onMoved: v => { Nbfc.safety = Math.round(70 + v * 30); Settings.setSafety(Nbfc.safety) }
    }
}
