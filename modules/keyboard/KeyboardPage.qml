import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// Klavye ışığı (tek bölge). Mantık services/Keyboard.qml'de; burası sadece görünüm.
// Düzen: solda seçili efektin ayarları, sağda efekt listesi, altta genel parlaklık.
Flickable {
    id: page
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    readonly property bool canWrite: Keyboard.available && Keyboard.writable
    readonly property bool breathing: Keyboard.effect === "breathing"
    readonly property bool animated: Keyboard.effect !== "static"     // nefes ya da renk geçişi
    // Renk kaynağı seçenekleri: renk geçişinde "seçilen renk" yok (tek renkle geçiş olmaz)
    readonly property var sources: breathing ? [{ id: "single", t: "Seçilen renk" }, { id: "multi", t: "Birden fazla" }, { id: "theme", t: "Caelestia" }]
                                             : [{ id: "multi", t: "Birden fazla" }, { id: "theme", t: "Caelestia" }]
    // Efekt listesi (yeni efektler buraya eklenir)
    readonly property var effects: [
        { id: "static", name: "Sabit", icon: "lightbulb", sub: "Tek renk, sürekli yanar" },
        { id: "breathing", name: "Nefes", icon: "airwave", sub: "Yavaşça yanıp söner" },
        { id: "cycle", name: "Renk geçişi", icon: "gradient", sub: "Renkler arasında akar" }
    ]
    readonly property var current: effects.find(e => e.id === Keyboard.effect) ?? effects[0]
    // Hazır renkler; ilki Caelestia temasının ana rengi
    readonly property var presets: [
        { name: "Caelestia", c: Colours.primary },
        { name: "Beyaz", c: "#ffffff" }, { name: "Kırmızı", c: "#ff0000" }, { name: "Turuncu", c: "#ff6000" },
        { name: "Sarı", c: "#ffd000" }, { name: "Yeşil", c: "#00ff00" }, { name: "Camgöbeği", c: "#00ffff" },
        { name: "Mavi", c: "#0040ff" }, { name: "Mor", c: "#8000ff" }, { name: "Pembe", c: "#ff00a0" }
    ]

    // Nefeste "birden fazla renk" seçiliyken renk çemberi listedeki seçili rengi düzenler
    property int editIndex: 0
    readonly property bool editingList: animated && Keyboard.source === "multi"
    readonly property bool themeLocked: animated && Keyboard.source === "theme"
    readonly property int editAt: Math.min(editIndex, Keyboard.colors.length - 1)
    readonly property color wheelColor: editingList ? Keyboard.colors[editAt] : Keyboard.color
    function pick(c) {
        if (!editingList) { Keyboard.setColor(c); return }
        const a = Keyboard.colors.slice()
        a[editAt] = Keyboard.hex(Qt.lighter(c, 1))
        Keyboard.setColors(a)
    }
    function pct(v) { return "%" + Math.round(v * 100) }

    // Pencere açılınca güncel durumu oku (Fn tuşlarıyla değişmiş olabilir)
    Component.onCompleted: Keyboard.refresh()

    ColumnLayout {
        id: col
        width: page.width
        spacing: 12

        // ---------- durum ----------
        Card {
            title: "Klavye ışığı"
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    implicitWidth: 44; implicitHeight: 44; radius: 14
                    color: Keyboard.rgb ? Keyboard.color : Colours.surfaceHigh
                    opacity: Keyboard.maxBrightness > 0 ? 0.35 + 0.65 * Keyboard.brightness / Keyboard.maxBrightness : 1
                    border { width: 2; color: Colours.outline }
                    StyledText {
                        anchors.centerIn: parent
                        visible: !Keyboard.rgb
                        text: "keyboard"
                        color: Colours.primary
                        font { family: Colours.iconFont; pixelSize: 24 }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        text: !Keyboard.ready ? "Okunuyor…" : Keyboard.available ? Keyboard.name : "Klavye ışığı bulunamadı"
                        color: Colours.fg
                        font { pixelSize: 15; bold: true }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: !Keyboard.available ? "Bu bilgisayarda çekirdeğin tanıdığı bir klavye ışığı yok."
                            : (Keyboard.rgb ? "RGB · tek bölge (tüm klavye tek renk)" : "Tek renk · sadece parlaklık")
                              + (Keyboard.rgb ? " · efekt: " + page.current.name : "")
                        color: Colours.fgDim
                        font.pixelSize: 11
                    }
                }
            }
            StyledText {
                visible: Keyboard.available && !Keyboard.writable && Keyboard.ready
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Işığa yazma izni yok. Kurulum, sadece bu ışığın renk ve parlaklık dosyalarına izin veren bir udev kuralı ekler: sudo make install"
                color: Colours.warning
                font.pixelSize: 12
            }
            StyledText {
                visible: Keyboard.error !== ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: Keyboard.error
                color: Colours.error
                font.pixelSize: 12
            }
        }

        // ---------- efekt: solda ayarlar, sağda liste ----------
        RowLayout {
            visible: Keyboard.rgb
            Layout.fillWidth: true
            spacing: 12
            enabled: page.canWrite
            opacity: enabled ? 1 : 0.4

            // Seçili efektin ayarları
            Card {
                Layout.alignment: Qt.AlignTop
                title: "Ayarlar · " + page.current.name

                // Nefes / renk geçişi ayarları
                ColumnLayout {
                    visible: page.animated
                    Layout.fillWidth: true
                    spacing: 10

                    StyledText { text: "Renkler"; color: Colours.fg; font.pixelSize: 13 }
                    Segment {
                        model: page.sources.map(x => x.t)
                        controlled: true
                        current: page.sources.findIndex(x => x.id === Keyboard.source)
                        onPicked: i => Keyboard.setSource(page.sources[i].id)
                    }

                    // Renk listesi (birden fazla) ya da tema renkleri; o an nefes alan renk halkalı
                    RowLayout {
                        visible: Keyboard.source !== "single"
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: Keyboard.source === "theme" ? Keyboard.themeColors : Keyboard.colors
                            Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool chosen: page.editingList && index === page.editAt
                                readonly property bool live: index === Keyboard.cycleIndex
                                width: 34; height: 34; radius: 17
                                color: modelData
                                border { width: chosen ? 3 : (live ? 2 : 1); color: chosen ? Colours.fg : (live ? Colours.primary : Colours.outline) }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: page.editingList
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: page.editIndex = parent.index
                                }
                            }
                        }
                        // Birden fazla: renk ekle/sil (en fazla 6). Caelestia: renk sayısı 3-6
                        StepBtn {
                            // Caelestia: temada eklenecek farklı renk kalmadıysa (vurgu renkleri yoksa) gösterme
                            visible: page.editingList ? Keyboard.colors.length < 6
                                   : (page.themeLocked && Keyboard.themeCount < 6 && Keyboard.themeColors.length >= Keyboard.themeCount)
                            icon: "add"
                            onActivated: {
                                if (page.themeLocked) { Keyboard.setThemeCount(Keyboard.themeCount + 1); return }
                                const a = Keyboard.colors.slice()
                                a.push(Keyboard.hex(page.wheelColor))
                                Keyboard.setColors(a)
                                page.editIndex = a.length - 1
                            }
                        }
                        StepBtn {
                            visible: page.editingList ? Keyboard.colors.length > (page.breathing ? 1 : 2) : (page.themeLocked && Keyboard.themeCount > 3)
                            icon: "remove"
                            onActivated: {
                                if (page.themeLocked) { Keyboard.setThemeCount(Keyboard.themeCount - 1); return }
                                const a = Keyboard.colors.slice()
                                a.splice(page.editAt, 1)
                                Keyboard.setColors(a)
                                page.editIndex = Math.max(0, Math.min(page.editIndex, a.length - 1))
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: Keyboard.source === "theme"
                            ? "Caelestia temanın renkleri (ana renk + temanın diğer renklerinden tonu en farklı olanlar; LED'de canlı görünsün diye doygunlukları artırıldı). + / − renk sayısını değiştirir (3-6). Tema değişince kendiliğinden güncellenir."
                            : Keyboard.source === "multi"
                            ? (page.breathing ? "Her nefeste sıradaki renk; renk ışık en karanlıktayken değişir." : "Renkler sırayla, yanıp sönmeden birbirine akar.")
                              + " Bir renge tıkla, aşağıdaki çemberle değiştir. + ekler, − seçileni siler (en fazla 6)."
                            : "Seçtiğin renk yanıp söner. Rengi aşağıdaki çemberden seç."
                        color: Colours.fgDim
                        font.pixelSize: 11
                    }

                    SliderRow {
                        id: speedRow
                        label: "Hız"
                        value: Keyboard.speed
                        readout: (page.breathing ? "bir nefes " : "renk başına ") + Keyboard.period.toFixed(1).replace(".", ",") + " sn"
                        onMoved: v => Keyboard.setSpeed(v)
                    }
                    SliderRow {
                        id: lowRow
                        visible: page.breathing
                        label: "En düşük"
                        value: Keyboard.minLevel
                        readout: Keyboard.minLevel === 0 ? "tamamen söner" : page.pct(Keyboard.minLevel)
                        onMoved: v => Keyboard.setRange(v, Keyboard.maxLevel)
                    }
                    SliderRow {
                        id: highRow
                        visible: page.breathing
                        label: "En yüksek"
                        value: Keyboard.maxLevel
                        readout: page.pct(Keyboard.maxLevel)
                        onMoved: v => Keyboard.setRange(Keyboard.minLevel, v)
                    }
                    // Kaydırıcılar sürüklenince bağı kopar; değer başka yerden değişince (diğer kaydırıcı itince, terminal) eşitle
                    Connections {
                        target: Keyboard
                        function onMinLevelChanged() { lowRow.value = Keyboard.minLevel }
                        function onMaxLevelChanged() { highRow.value = Keyboard.maxLevel }
                        function onSpeedChanged() { speedRow.value = Keyboard.speed }
                    }
                    StyledText {
                        visible: page.breathing
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "Seviyeler, alttaki genel parlaklığa göredir. En düşük %0 değilse ışık hiç sönmez."
                        color: Colours.fgDim
                        font.pixelSize: 11
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colours.outline; opacity: 0.5 }
                }

                // Sabit efektinde açıklama
                StyledText {
                    visible: !page.animated
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Klavye seçtiğin renkte sabit yanar."
                    color: Colours.fgDim
                    font.pixelSize: 11
                }

                // Renk seçimi (her iki efektte; Caelestia kaynağında kilitli)
                StyledText {
                    text: page.themeLocked ? "Renkler Caelestia temasından geliyor"
                        : page.editingList ? "Renk · " + (page.editAt + 1) + ". renk" : "Renk"
                    color: Colours.fg
                    font.pixelSize: 13
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    enabled: !page.themeLocked
                    opacity: enabled ? 1 : 0.4

                    ColorWheel {
                        Layout.alignment: Qt.AlignHCenter
                        hue: page.wheelColor.hsvHue < 0 ? 0 : page.wheelColor.hsvHue
                        sat: page.wheelColor.hsvSaturation
                        onPicked: (h, s) => page.pick(Qt.hsva(h, s, 1, 1))
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: page.presets
                            Rectangle {
                                required property var modelData
                                width: 34; height: 34; radius: 17
                                color: modelData.c
                                border { width: 2; color: Colours.outline }
                                StyledText {
                                    visible: parent.modelData.name === "Caelestia"
                                    anchors.centerIn: parent
                                    text: "palette"
                                    color: Colours.fgOnPrimary
                                    font { family: Colours.iconFont; pixelSize: 18 }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.pick(parent.modelData.c)
                                }
                            }
                        }
                    }
                }
            }

            // Efekt listesi: tıklanan efekt etkinleşir
            Card {
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: false
                Layout.preferredWidth: 210
                title: "Efektler"
                gap: 6

                Repeater {
                    model: page.effects
                    Rectangle {
                        id: item
                        required property var modelData
                        readonly property bool on: Keyboard.effect === modelData.id
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: 14
                        color: on ? Colours.primary : (ma.containsMouse ? Colours.surfaceHigh : "transparent")
                        Behavior on color { CAnim {} }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 10
                            StyledText {
                                text: item.modelData.icon
                                color: item.on ? Colours.fgOnPrimary : Colours.primary
                                font { family: Colours.iconFont; pixelSize: 22 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    text: item.modelData.name
                                    color: item.on ? Colours.fgOnPrimary : Colours.fg
                                    font { pixelSize: 14; bold: true }
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: item.modelData.sub
                                    color: item.on ? Colours.fgOnPrimary : Colours.fgDim
                                    opacity: 0.8
                                    font.pixelSize: 11
                                }
                            }
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Keyboard.setEffect(item.modelData.id)
                        }
                    }
                }
            }
        }

        // ---------- genel parlaklık ----------
        Card {
            visible: Keyboard.available
            title: "Parlaklık"
            enabled: page.canWrite
            opacity: enabled ? 1 : 0.4

            SliderRow {
                id: bright
                label: "Parlaklık"
                value: Keyboard.maxBrightness > 0 ? Keyboard.brightness / Keyboard.maxBrightness : 0
                readout: Math.round(value * 100) + "%"
                onMoved: v => Keyboard.setBrightness(v * Keyboard.maxBrightness)
            }
            // Kaydırıcı sürüklenince bağı kopar; parlaklık başka yerden (butonlar, terminal) değişince eşitle
            Connections {
                target: Keyboard
                function onBrightnessChanged() {
                    if (Keyboard.maxBrightness > 0) bright.value = Keyboard.brightness / Keyboard.maxBrightness
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [{ t: "Kapalı", v: 0 }, { t: "%25", v: 0.25 }, { t: "%50", v: 0.5 }, { t: "%100", v: 1 }]
                    Btn {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.t
                        onClicked: Keyboard.setBrightness(modelData.v * Keyboard.maxBrightness)
                    }
                }
            }
        }
    }
}
