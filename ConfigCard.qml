import QtQuick
import QtQuick.Layouts

Card {
    id: cfg
    title: "NBFC config"
    property string picked: ""
    property bool open: false
    readonly property string sel: picked !== "" ? picked : Nbfc.configId
    readonly property string q: search.text.toLowerCase()
    readonly property var shown: {
        const f = Nbfc.configs.filter(c => c.toLowerCase().indexOf(q) >= 0)
        const rec = Nbfc.recommended
        return f.filter(c => rec.indexOf(c) >= 0).concat(f.filter(c => rec.indexOf(c) < 0))
    }

    Connections {
        target: Nbfc
        function onRecommendedChanged() {
            if (Nbfc.recommended.length > 0) cfg.picked = Nbfc.recommended[0]
        }
        function onConfigIdChanged() { cfg.picked = "" }
    }

    // Başlık satırı: tıkla -> listeyi aç/kapat
    Item {
        Layout.fillWidth: true
        implicitHeight: 48
        RowLayout {
            anchors.fill: parent
            spacing: 12
            Text { text: "tune"; color: Colours.primary; font { family: Colours.iconFont; pixelSize: 24 } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: Nbfc.configId !== "" ? Nbfc.configId : "Config seçilmedi"
                    elide: Text.ElideRight
                    color: Colours.fg
                    font { pixelSize: 15; bold: true }
                }
                Text {
                    text: Nbfc.fans.length > 0 ? Nbfc.fans.length + " fan bulundu" : "Fan bilgisi yok"
                    color: Colours.fgDim
                    font.pixelSize: 11
                }
            }
            Text {
                text: "expand_more"
                color: Colours.fgDim
                rotation: cfg.open ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 150 } }
                font { family: Colours.iconFont; pixelSize: 24 }
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cfg.open = !cfg.open }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: cfg.open
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: 20
            color: Colours.surfaceHigh
            Text {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "search"
                color: Colours.fgDim
                font { family: Colours.iconFont; pixelSize: 20 }
            }
            Text {
                visible: search.text === ""
                x: 44
                anchors.verticalCenter: parent.verticalCenter
                text: "Config ara…"
                color: Colours.fgDim
                font.pixelSize: 13
            }
            TextInput {
                id: search
                anchors { fill: parent; leftMargin: 44; rightMargin: 14 }
                verticalAlignment: TextInput.AlignVCenter
                color: Colours.fg
                selectByMouse: true
                clip: true
                font.pixelSize: 13
            }
        }

        Text {
            Layout.fillWidth: true
            text: Nbfc.configNote
            wrapMode: Text.WordWrap
            color: Colours.fgDim
            font.pixelSize: 11
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: 228
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: cfg.shown
            delegate: Rectangle {
                readonly property bool chosen: cfg.sel === modelData
                width: ListView.view.width
                height: 38
                radius: 12
                color: chosen ? Colours.primary : (ma.containsMouse ? Colours.surfaceHigh : "transparent")
                Text {
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14; right: tag.left; rightMargin: 8 }
                    text: modelData
                    elide: Text.ElideRight
                    color: chosen ? Colours.fgOnPrimary : Colours.fg
                    font.pixelSize: 13
                }
                Row {
                    id: tag
                    anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
                    spacing: 8
                    Text {
                        visible: Nbfc.recommended.indexOf(modelData) >= 0
                        text: "önerilen"
                        color: chosen ? Colours.fgOnPrimary : Colours.fgDim
                        font.pixelSize: 11
                    }
                    Text {
                        visible: modelData === Nbfc.configId
                        text: "check"
                        color: chosen ? Colours.fgOnPrimary : Colours.primary
                        font { family: Colours.iconFont; pixelSize: 18 }
                    }
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cfg.picked = modelData }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            Btn {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: "auto_awesome"; text: "Önerileni bul"
                onClicked: Nbfc.recommend()
            }
            Btn {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                filled: true; icon: "check"; text: "Uygula"
                enabled: cfg.sel !== "" && cfg.sel !== Nbfc.configId
                opacity: enabled ? 1 : 0.4
                onClicked: Nbfc.applyConfig(cfg.sel)
            }
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Colours.fgDim
            font.pixelSize: 11
            text: "Uygulamak servisi yeniden başlatır ve yönetici izni ister. Uyumsuz bir config fanları yanlış sürebilir; önce salt-okunur modda dene."
        }
    }
}
