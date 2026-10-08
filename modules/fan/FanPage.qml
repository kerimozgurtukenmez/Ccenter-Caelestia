import QtQuick
import QtQuick.Layouts
import qs.services

Flickable {
    id: page
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    // Global kapanınca her fan kendi kartındaki ayara döner; açılınca global kartın ayarı hepsine yazılır
    function reapply() {
        if (globalCard.globalOn) {
            Nbfc.applyTarget(-1, globalCard.st)
        } else {
            for (let i = 0; i < fanRep.count; i++) Nbfc.applyTarget(i, fanRep.itemAt(i).st)
        }
    }

    ColumnLayout {
        id: col
        width: page.width
        spacing: 12

        TempCard {}
        ServiceCard {}
        ConfigCard {}

        // Servis durmuşken ya da salt-okunur modda fan ayarları kilitli
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            enabled: Nbfc.running && !Nbfc.readOnly
            opacity: enabled ? 1 : 0.35
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Text {
                visible: Nbfc.fans.length === 0
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Fan bilgisi yok. Servis çalışmıyor ya da config seçilmemiş olabilir."
                color: Colours.fgDim
                font.pixelSize: 12
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
                        name: "Fan " + (index + 1)
                        subtitle: info ? info.name : ""
                        info: Nbfc.fans[index]
                        active: !globalCard.globalOn
                        onEdited: Nbfc.applyTarget(index, st)
                    }
                }
            }

            FanCard {
                id: globalCard
                visible: Nbfc.fans.length > 0
                isGlobal: true
                name: "Global"
                subtitle: "Açıkken tüm fanlara aynı değerler yazılır"
                onEdited: if (globalOn) Nbfc.applyTarget(-1, st)
                onGlobalOnChanged: page.reapply()
            }
        }
    }
}
