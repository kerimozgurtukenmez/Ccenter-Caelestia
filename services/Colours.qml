pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import Caelestia.Config
import Caelestia.Images

// Renkler Caelestia'dan gelir, Caelestia dosyalarına hiçbir şey yazılmaz (sadece okunur):
//  - ~/.local/state/caelestia/scheme.json  -> renk şeması
//  - Tokens.transparency (shell.json)       -> şeffaflık; pencere yarı saydam olunca Hyprland blur'u uygular
//  - wallpaper/path.txt                     -> duvar kağıdı parlaklığı (katman renklerini Caelestia gibi ayarlamak için)
Singleton {
    id: root

    // Şemadan gelen ham renkler (yoksa varsayılanlar)
    QtObject {
        id: raw
        property color surface: "#141218"
        property color surfaceContainer: "#211f26"
        property color surfaceContainerHigh: "#2b2930"
    }
    property color primary: "#d0bcff"
    property color fgOnPrimary: "#381e72"
    property color fg: "#e6e0e9"
    property color fgDim: "#cac4d0"
    property color outline: "#49454f"
    property color error: "#f2b8b5"
    property color success: "#b5ccba"
    property color warning: "#ffcc80"
    property color tertiary: "#efb8c8"
    property color sky: "#89dceb"
    property bool light: false
    readonly property string iconFont: "Material Symbols Rounded"
    readonly property string fontFamily: Tokens.font.body.small.family

    // Arka planlar şeffaflık katmanından geçer: pencere (0) < kart (1) < kart içi (2)
    readonly property color surface: layer(raw.surface, 0)
    readonly property color surfaceContainer: layer(raw.surfaceContainer, 1)
    readonly property color surfaceHigh: layer(raw.surfaceContainerHigh, 2)

    // ---------- Caelestia şeffaflığı (services/Colours.qml ile aynı hesap) ----------
    readonly property bool trEnabled: Tokens.transparency.enabled
    readonly property real trBase: Math.max(0, Math.min(1, Tokens.transparency.base - (light ? 0.1 : 0)))
    readonly property real trLayers: Math.max(0, Math.min(1, Tokens.transparency.layers))
    readonly property real wallLuminance: wallLuminanceSafe

    function luminance(c) {
        if (c.r == 0 && c.g == 0 && c.b == 0) return 0
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2))
    }
    function alter(c, a, layer) {
        const lum = luminance(c)
        const offset = (!light || layer == 1 ? 1 : -layer / 2) * (light ? 0.2 : 0.3) * (1 - trBase)
                     * (1 + wallLuminance * (light ? (layer == 1 ? 3 : 1) : 2.5))
        const scale = lum > 0 ? (lum + offset) / lum : 1
        return Qt.rgba(Math.max(0, Math.min(1, c.r * scale)), Math.max(0, Math.min(1, c.g * scale)),
                       Math.max(0, Math.min(1, c.b * scale)), a)
    }
    function layer(c, layer) {
        if (!trEnabled) return c
        return layer === 0 ? Qt.alpha(c, trBase) : alter(c, trLayers, layer ?? 1)
    }

    // property adı -> scheme.json'daki anahtar (olmayan anahtar atlanır, varsayılan kalır)
    readonly property var keys: ({
        primary: "primary", fgOnPrimary: "onPrimary", fg: "onSurface", fgDim: "onSurfaceVariant",
        outline: "outlineVariant", error: "error", success: "success", warning: "yellow", tertiary: "tertiary", sky: "sky"
    })
    readonly property var rawKeys: ({
        surface: "surface", surfaceContainer: "surfaceContainer", surfaceContainerHigh: "surfaceContainerHigh"
    })

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/caelestia"

    FileView {
        path: root.stateDir + "/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const s = JSON.parse(text())
            const c = s.colours
            root.light = s.mode === "light"
            for (const k in root.keys)
                if (c[root.keys[k]]) root[k] = "#" + c[root.keys[k]]
            for (const k in root.rawKeys)
                if (c[root.rawKeys[k]]) raw[k] = "#" + c[root.rawKeys[k]]
        }
    }

    FileView {
        id: wall
        path: root.stateDir + "/wallpaper/path.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.wallpaper = text().trim()
    }
    property string wallpaper: ""

    // Video duvar kağıdı analiz edilemez; Caelestia'da da parlaklık bu durumda 0 kalır
    readonly property bool wallIsImage: root.wallpaper !== "" && !/\.(mp4|mkv|webm|avi|mov)$/i.test(root.wallpaper)
    readonly property real wallLuminanceSafe: wallIsImage ? analyser.luminance : 0

    ImageAnalyser {
        id: analyser
        source: root.wallIsImage ? root.wallpaper : ""
    }
}
