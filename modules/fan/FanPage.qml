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

    // Sadece görünüm: fan ayarları, profiller ve geri yükleme services/FanState.qml'de
    ColumnLayout {
        id: col
        width: page.width
        spacing: 12

        TempCard {}
        HistoryCard {}
        ServiceCard {}
        ConfigCard {}

        // Servis durmuşken ya da salt-okunur modda fan ayarları kilitli
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
                text: "Fan bilgisi yok. Servis çalışmıyor ya da config seçilmemiş olabilir."
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
                        name: "Fan " + (index + 1)
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
                subtitle: "Açıkken tüm fanlara aynı değerler yazılır"
            }
        }

        NotifyCard {}
        BackgroundCard {}
    }
}
