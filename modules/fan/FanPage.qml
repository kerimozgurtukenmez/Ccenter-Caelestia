import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

Flickable {
    id: page
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    // View only: fan settings, profiles and restoring live in services/FanState.qml
    ColumnLayout {
        id: col
        width: page.width
        spacing: 12

        TempCard {}
        HistoryCard {}
        ServiceCard {}
        ConfigCard {}

        // Fan settings are locked while the service is stopped or in read-only mode
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            enabled: Nbfc.running && !Nbfc.readOnly
            opacity: enabled ? 1 : 0.35
            Behavior on opacity { Anim {} }

            StyledText {
                visible: Nbfc.fans.length === 0
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: I18n.t("No fan information. The service may not be running or no config is selected.")
                color: Colours.fgDim
                font.pixelSize: 12
            }

            ProfileCard {
                visible: Nbfc.fans.length > 0
            }

            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(1, Math.min(Nbfc.fans.length, 2))
                columnSpacing: 12
                rowSpacing: 12
                Repeater {
                    id: fanRep
                    model: Nbfc.fans.length
                    FanCard {
                        Layout.alignment: Qt.AlignTop
                        fanIndex: index
                        name: I18n.t("Fan %1").arg(index + 1)
                        subtitle: info ? info.name : ""
                        info: Nbfc.fans[index]
                        active: !FanState.globalOn
                    }
                }
            }

            FanCard {
                visible: Nbfc.fans.length > 0
                isGlobal: true
                name: "Global"
                subtitle: I18n.t("When on, the same settings are written to every fan")
            }
        }

        NotifyCard {}
        BackgroundCard {}
    }
}
