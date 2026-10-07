import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ShellRoot {
    // FloatingWindow = normal xdg pencere (Hyprland tile'lar). PanelWindow layer-shell'dir, tile olmaz.
    FloatingWindow {
        id: win
        title: "Ccenter-Caelestia"
        visible: true
        implicitWidth: 600
        implicitHeight: 780
        color: Colours.surface

        property int tab: 0

        ColumnLayout {
            anchors { fill: parent; margins: 20 }
            spacing: 16

            Row {
                Text { text: "Ccenter"; color: Colours.fg; font { pixelSize: 26; bold: true } }
                Text { text: "-Caelestia"; color: Colours.primary; font { pixelSize: 26; bold: true } }
            }

            RowLayout {
                spacing: 12
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
                FanPage {}
                KeyboardPage {}
            }
        }
    }

    Binding { target: Sensors; property: "active"; value: win.visible && win.tab === 0 }

    IpcHandler {
        target: "cc"
        function toggle(): void { win.visible = !win.visible }
    }
}
