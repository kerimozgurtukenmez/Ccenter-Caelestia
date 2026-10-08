pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property color primary: "#d0bcff"
    property color fgOnPrimary: "#381e72"
    property color surface: "#141218"
    property color surfaceContainer: "#211f26"
    property color surfaceHigh: "#2b2930"
    property color fg: "#e6e0e9"
    property color fgDim: "#cac4d0"
    property color outline: "#49454f"
    readonly property string iconFont: "Material Symbols Rounded"

    // property adı -> scheme.json'daki anahtar (olmayan anahtar atlanır, varsayılan kalır)
    readonly property var keys: ({
        primary: "primary", fgOnPrimary: "onPrimary", surface: "surface",
        surfaceContainer: "surfaceContainer", surfaceHigh: "surfaceContainerHigh",
        fg: "onSurface", fgDim: "onSurfaceVariant", outline: "outlineVariant"
    })

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const c = JSON.parse(text()).colours
            for (const k in root.keys)
                if (c[root.keys[k]]) root[k] = "#" + c[root.keys[k]]
        }
    }
}
