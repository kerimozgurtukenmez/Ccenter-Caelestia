pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property color primary: "#d0bcff"
    property color surface: "#141218"

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const c = JSON.parse(text()).colours
            root.primary = "#" + c.primary
            root.surface = "#" + c.surface
        }
    }
}