import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// Fan profilleri: hazırlar + kullanıcının kaydettikleri (NBFC config'ine göre ayrı tutulur)
Card {
    id: card
    title: "Profiller"

    readonly property string cfgId: Nbfc.configId
    readonly property var custom: Settings.profilesOf(cfgId)
    readonly property string active: Settings.activeOf(cfgId)
    readonly property var all: FanState.builtins.map(p => Object.assign({ builtin: true }, p))
                                   .concat(custom.map(p => Object.assign({ builtin: false, icon: "tune" }, p)))
    readonly property string newName: nameInput.text.trim()
    readonly property bool nameTaken: FanState.builtins.some(p => p.name === newName)
    property string confirmDelete: ""        // silmek için ikinci tık

    StyledText {
        Layout.fillWidth: true
        text: card.active !== "" ? "Aktif: " + card.active : "Özel ayarlar (profil seçili değil)"
        color: Colours.fgDim
        font.pixelSize: 11
    }

    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: card.all
            Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: modelData.name === card.active
                readonly property bool deleting: card.confirmDelete === modelData.name
                implicitHeight: 36
                implicitWidth: row.implicitWidth + 28
                radius: height / 2
                color: deleting ? Colours.error : (on ? Colours.primary : Colours.surfaceHigh)
                Behavior on color { CAnim {} }

                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    spacing: 6
                    StyledText {
                        text: chip.modelData.icon
                        color: chip.on || chip.deleting ? Colours.fgOnPrimary : Colours.primary
                        font { family: Colours.iconFont; pixelSize: 18 }
                    }
                    StyledText {
                        text: chip.deleting ? "Silinsin mi?" : chip.modelData.name
                        color: chip.on || chip.deleting ? Colours.fgOnPrimary : Colours.fg
                        font { pixelSize: 13; bold: true }
                    }
                    // Kendi profillerinde sil düğmesi (tıklama alanı aşağıda, en üstte)
                    StyledText {
                        id: closeIcon
                        visible: !chip.modelData.builtin
                        text: "close"
                        color: chip.on || chip.deleting ? Colours.fgOnPrimary : Colours.fgDim
                        font { family: Colours.iconFont; pixelSize: 16 }
                    }
                }
                // Tıklama alanları içerikten sonra gelir ki üstte kalsın (z: -1 tıklamaları yutuyordu)
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        console.log("[ccenter] profil butonu: " + chip.modelData.name)
                        if (chip.deleting) { card.confirmDelete = ""; return }   // silmekten vazgeç
                        card.confirmDelete = ""
                        console.log("[ccenter] " + FanState.applyByName(chip.modelData.name, false))
                    }
                }
                MouseArea {
                    visible: closeIcon.visible
                    x: row.x + closeIcon.x - 6
                    y: 0
                    width: closeIcon.width + 12
                    height: chip.height
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (chip.deleting) {
                            Settings.removeProfile(card.cfgId, chip.modelData.name)
                            card.confirmDelete = ""
                        } else {
                            card.confirmDelete = chip.modelData.name
                        }
                    }
                }
            }
        }
    }

    // Maksimum fan: tüm fanlar %100, süre dolunca her fan kendi ayarına döner
    property double now: Date.now()
    Timer { running: Nbfc.boostUntil > 0; interval: 1000; repeat: true; triggeredOnStart: true; onTriggered: card.now = Date.now() }
    function left() {
        const s = Math.max(0, Math.round((Nbfc.boostUntil - now) / 1000))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        StyledText {
            text: "air"
            color: Nbfc.boosting ? Colours.error : Colours.primary
            font { family: Colours.iconFont; pixelSize: 22 }
        }
        StyledText {
            Layout.fillWidth: true
            text: Nbfc.boosting ? "Maksimum fan açık" + (Nbfc.boostUntil > 0 ? " · " + card.left() + " kaldı" : "") : "Maksimum fan"
            color: Nbfc.boosting ? Colours.error : Colours.fg
            font { pixelSize: 13; bold: Nbfc.boosting }
        }
        Repeater {
            model: Nbfc.boosting ? [] : [{ t: "5 dk", m: 5 }, { t: "15 dk", m: 15 }, { t: "Süresiz", m: -1 }]
            Btn {
                required property var modelData
                text: modelData.t
                onClicked: Nbfc.setBoost(modelData.m)
            }
        }
        Btn {
            visible: Nbfc.boosting
            icon: "close"
            text: "Kapat"
            filled: true
            onClicked: Nbfc.setBoost(0)
        }
    }

    // Mevcut ayarları profil olarak kaydet
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            radius: 19
            color: Colours.surfaceHigh
            StyledText {
                visible: nameInput.text === ""
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "Mevcut ayarları kaydet: profil adı…"
                color: Colours.fgDim
                font.pixelSize: 13
            }
            TextInput {
                id: nameInput
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                verticalAlignment: TextInput.AlignVCenter
                color: Colours.fg
                selectByMouse: true
                clip: true
                maximumLength: 32
                font { family: Colours.fontFamily; pixelSize: 13 }
                onAccepted: save.clicked()
            }
        }
        Btn {
            id: save
            icon: "save"
            text: "Kaydet"
            filled: true
            enabled: card.newName !== "" && !card.nameTaken
            opacity: enabled ? 1 : 0.4
            onClicked: {
                if (!enabled) return
                Settings.saveProfile(card.cfgId, FanState.snapshot(card.newName))
                Settings.setActive(card.cfgId, card.newName)
                nameInput.text = ""
            }
        }
    }
    StyledText {
        visible: card.nameTaken
        text: "Bu ad hazır bir profile ait, başka bir ad seç."
        color: Colours.error
        font.pixelSize: 11
    }
}
