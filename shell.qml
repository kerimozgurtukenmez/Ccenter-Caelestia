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
    id: root
    // Pencere durumu pencerenin dışında tutulur: pencere kapanınca tamamen yok edilir
    // (arayüz, grafik bağlamı ve çizim önbellekleri bellekten silinir; fan kontrolü FanState'te sürer)
    // Servisle (CCENTER_BACKGROUND=1) başlarsa pencere açılmadan arka planda çalışır
    property bool shown: Quickshell.env("CCENTER_BACKGROUND") !== "1"
    property int tab: 0

    LazyLoader {
        active: root.shown
        // FloatingWindow = normal xdg pencere (Hyprland tile'lar). PanelWindow layer-shell'dir, tile olmaz.
        FloatingWindow {
            title: "Ccenter-Caelestia"
            visible: true
            // Pencere kapatılınca uygulama kapanmaz, arka planda devam eder (open ile geri açılır)
            onClosed: root.shown = false
            implicitWidth: 600
            implicitHeight: 780
            color: Colours.surface
            // Caelestia token'ları ekrana göre çalışır (köşe, boşluk vb.)
            contentItem.Tokens.screen: screen?.name ?? ""

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
                        active: root.tab === 0; onClicked: root.tab = 0
                    }
                    NavButton {
                        icon: "keyboard"; label: "Klavye"; sub: "RGB · renk ve parlaklık"
                        active: root.tab === 1; onClicked: root.tab = 1
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.tab
                    FanPage {}
                    KeyboardPage {}
                }
            }
        }
    }
    onShownChanged: if (!shown) gcTimer.restart()

    Timer { id: gcTimer; interval: 1000; onTriggered: gc() }

    // Sensörler: Fan sekmesi açıkken, Ccenter fan kontrol ederken ya da bildirimler açıkken (kritik sıcaklık için) okunur
    Binding { target: Sensors; property: "active"; value: (root.shown && root.tab === 0) || Nbfc.needsSensors || Notify.enabled }
    // Her zaman çalışan servisler (pencere kapalıyken de): olay izleyici ve fan durumu
    readonly property var alerts: Alerts
    readonly property var fanState: FanState
    readonly property var keyboard: Keyboard     // klavye efekti pencere kapalıyken de çalışsın
    // Tempo: pencere açıkken ya da fan kontrol ederken hızlı, değilse sakin (performans)
    Binding { target: Nbfc; property: "uiVisible"; value: root.shown }
    Binding { target: Sensors; property: "fast"; value: root.shown || Nbfc.controlling }

    // Sistem tepsisi (Caelestia barı): sol tık pencereyi açar/gizler, menüde profiller ve maksimum fan
    Binding { target: Tray; property: "windowVisible"; value: root.shown }
    Binding { target: Tray; property: "profiles"; value: FanState.allProfiles().map(p => p.name) }
    Binding { target: Tray; property: "active"; value: Settings.activeOf(Nbfc.configId) }
    Binding { target: Tray; property: "boost"; value: Nbfc.boosting }
    Binding {
        target: Tray; property: "tooltip"
        value: (Settings.activeOf(Nbfc.configId) || "Özel ayarlar")
               + (isFinite(Nbfc.temp) ? " · CPU " + Math.round(Nbfc.temp) + "°C" : "")
               + (isFinite(Sensors.gpu) ? " · GPU " + Math.round(Sensors.gpu) + "°C" : "")
               + (Nbfc.boosting ? " · Maksimum fan" : "")
    }
    Connections {
        target: Tray
        function onToggleRequested() { root.shown = !root.shown }
        function onProfileRequested(name) { FanState.applyByName(name, false) }
    }

    // Terminalden kontrol: qs -c Ccenter ipc call cc <komut> [argüman]
    IpcHandler {
        target: "cc"
        function toggle(): void { root.shown = !root.shown }
        function open(): void { root.shown = true }
        function hide(): void { root.shown = false }
        // Tamamen kapat: kontrol edilen fanlar NBFC'nin otomatik kontrolüne döner
        function quit(): void { Nbfc.releaseAndQuit() }
        // Profil uygular (arayüzdeki butonla aynı kod). Büyük/küçük harf fark etmez.
        function profile(name: string): string { return FanState.applyByName(name, true) }
        // Maksimum fan: dakika (0 = kapat, -1 = süresiz)
        function boost(minutes: int): string {
            Nbfc.setBoost(minutes)
            return minutes === 0 ? "Maksimum fan kapatıldı" : "Maksimum fan açık" + (minutes > 0 ? " (" + minutes + " dk)" : " (süresiz)")
        }
        function profiles(): string { return FanState.profileList() }
        // Klavye ışığı: renk "#rrggbb", parlaklık yüzde (0-100)
        function kbd(): string { return Keyboard.statusText() }
        function kbdColor(hex: string): string {
            if (!Keyboard.rgb) return "Bu klavye ışığı RGB değil"
            if (!/^#?[0-9a-fA-F]{6}$/.test(hex)) return "Renk #rrggbb biçiminde olmalı (ör. #ff0000)"
            Keyboard.setColor(hex.startsWith("#") ? hex : "#" + hex)
            return Keyboard.writable ? "Renk: " + Keyboard.hex(Keyboard.color) : "Yazma izni yok: kurulum gerekli (sudo make install)"
        }
        function kbdEffect(name: string): string {
            if (["static", "breathing", "cycle"].indexOf(name) < 0) return "Efekt: static | breathing | cycle"
            if (!Keyboard.rgb) return "Bu klavye ışığı RGB değil"
            Keyboard.setEffect(name)
            return Keyboard.writable ? "Efekt: " + name : "Yazma izni yok: kurulum gerekli (sudo make install)"
        }
        function kbdSource(name: string): string {
            if (["single", "multi", "theme"].indexOf(name) < 0) return "Renk kaynağı: single | multi | theme"
            Keyboard.setSource(name)
            return "Renk kaynağı: " + name
        }
        function kbdSpeed(percent: int): string {
            Keyboard.setSpeed(Math.max(0, Math.min(100, percent)) / 100)
            return "Hız: %" + Math.round(Keyboard.speed * 100) + " (bir nefes " + Keyboard.period.toFixed(1) + " sn)"
        }
        // Caelestia kaynağında renk sayısı (3-6)
        function kbdThemeCount(n: int): string {
            Keyboard.setThemeCount(n)
            return "Caelestia renk sayısı: " + Keyboard.themeCount + " (" + Keyboard.themeColors.map(c => Keyboard.hex(c)).join(" ") + ")"
        }
        // Nefesin en düşük ve en yüksek seviyesi (yüzde)
        function kbdRange(low: int, high: int): string {
            Keyboard.setRange(low / 100, high / 100)
            return "Nefes aralığı: %" + Math.round(Keyboard.minLevel * 100) + " – %" + Math.round(Keyboard.maxLevel * 100)
        }
        function kbdBrightness(percent: int): string {
            if (!Keyboard.available) return "Klavye ışığı bulunamadı"
            Keyboard.setBrightness(Math.max(0, Math.min(100, percent)) * Keyboard.maxBrightness / 100)
            return Keyboard.writable ? "Parlaklık: %" + Math.max(0, Math.min(100, percent)) : "Yazma izni yok: kurulum gerekli (sudo make install)"
        }
        function status(): string { return FanState.statusText() }
    }
}
