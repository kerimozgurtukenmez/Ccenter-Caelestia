import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    PanelWindow {
        id: win
        visible: false
        implicitWidth: 520
        implicitHeight: 620
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: "#1e1e2e"
            Text { anchors.centerIn: parent; text: "Control Center"; color: "white" }
        }
    }

    IpcHandler {
        target: "cc"
        function toggle(): void { win.visible = !win.visible }
    }
}