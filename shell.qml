//@ pragma AppId ccenter
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.modules.fan
import qs.modules.keyboard
import qs.services

ShellRoot {
    // FloatingWindow = normal xdg pencere (Hyprland tile'lar). PanelWindow layer-shell'dir, tile olmaz.
    FloatingWindow {
        id: win
        title: "Ccenter-Caelestia"
        // Servisle (CCENTER_BACKGROUND=1) başlarsa pencere açılmadan arka planda çalışır
        visible: Quickshell.env("CCENTER_BACKGROUND") !== "1"
        // Pencere kapatılınca uygulama kapanmaz, arka planda devam eder (open ile geri açılır)
        onClosed: visible = false
        implicitWidth: 600
        implicitHeight: 780
        color: Colours.surface
        // Caelestia token'ları ekrana göre çalışır (köşe, boşluk vb.)
        contentItem.Tokens.screen: screen?.name ?? ""

        property int tab: 0

        ColumnLayout {
            anchors { fill: parent; margins: Tokens.padding.largeIncreased }
            spacing: Tokens.spacing.large

            Row {
                StyledText { text: "Ccenter"; color: Colours.fg; font { pixelSize: 26; bold: true } }
                StyledText { text: "-Caelestia"; color: Colours.primary; font { pixelSize: 26; bold: true } }
            }

            RowLayout {
                spacing: Tokens.spacing.medium
                NavButton {
                    icon: "mode_fan"; label: "Fan Kontrol"; sub: "NBFC · RPM ve eğri"
                    active: win.tab === 0; onClicked: win.tab = 0
                }
                NavButton {
                    icon: "keyboard"; label: "Klavye"; sub: "RGB · ışık modları"
                    active: win.tab === 1; onClicked: win.tab = 1
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: win.tab
                FanPage { id: fanPage }
                KeyboardPage {}
            }
        }
    }

    Binding { target: Sensors; property: "active"; value: (win.visible && win.tab === 0) || Nbfc.needsSensors }

    // Terminalden kontrol: qs -c Ccenter ipc call cc <komut> [argüman]
    IpcHandler {
        target: "cc"
        function toggle(): void { win.visible = !win.visible }
        function open(): void { win.visible = true }
        function hide(): void { win.visible = false }
        // Tamamen kapat: kontrol edilen fanlar NBFC'nin otomatik kontrolüne döner
        function quit(): void { Nbfc.releaseAndQuit() }
        // Profil uygular (arayüzdeki butonla aynı kod). Büyük/küçük harf fark etmez.
        function profile(name: string): string { return fanPage.applyByName(name) }
        function profiles(): string { return fanPage.profileList() }
        function status(): string { return fanPage.statusText() }
    }
}
