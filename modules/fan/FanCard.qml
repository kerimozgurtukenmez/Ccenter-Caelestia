import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

Card {
    id: fan
    property string name: "Fan"
    property string subtitle: ""
    property bool isGlobal: false
    property int fanIndex: 0
    property bool active: true               // global açıkken tekil kartlar false olur
    property var info: null                  // Nbfc.fans[i] (global kartta null)
    // Kart FanState'in görünümüdür: ayar oradan gelir, değişiklik oraya gider (pencere kapanınca kart silinir)
    readonly property var source: isGlobal ? FanState.globalSt : (FanState.fanSt[fanIndex] ?? FanState.autoSt)
    property int mode: 0
    property bool smoothCurve: true
    property string src: "cpu"               // Eğri modunda bakılan sıcaklık: cpu | gpu | max
    readonly property var srcKeys: ["cpu", "gpu", "max"]
    property int hyst: 3                     // Eğri: yavaşlamadan önce sıcaklığın inmesi gereken derece
    property var curve: [{ t: 45, s: 20 }, { t: 55, s: 40 }, { t: 65, s: 60 }, { t: 75, s: 80 }, { t: 85, s: 100 }]
    readonly property bool allowed: isGlobal ? FanState.globalOn : active
    // mode: 0 Otomatik, 1 Sabit, 2 Eğri
    readonly property var st: ({ mode: fan.mode, fixed: fixedRow.value, curve: fan.curve, smooth: fan.smoothCurve, src: fan.src, hyst: fan.hyst })

    // Kullanıcı bir şeyi değiştirdi: 400 ms bekleyip bir kez FanState'e yaz
    function touch() { debounce.restart() }
    Timer {
        id: debounce
        interval: 400
        onTriggered: fan.isGlobal ? FanState.setGlobal(fan.st) : FanState.setFan(fan.fanIndex, fan.st)
    }
    // FanState değişince (açılış, profil, terminal) kartı ona eşitle
    function sync() {
        const s = source
        if (!s) return
        curve = s.curve
        smoothCurve = s.smooth
        src = s.src
        hyst = s.hyst
        fixedRow.value = s.fixed
        mode = s.mode
    }
    onSourceChanged: if (!debounce.running) sync()
    // Pencere kapanınca kart silinir: bekleyen (400 ms) değişiklik kaybolmasın, hemen FanState'e yaz
    Component.onDestruction: if (debounce.running) {
        debounce.stop()
        fan.isGlobal ? FanState.setGlobal(fan.st) : FanState.setFan(fan.fanIndex, fan.st)
    }
    Component.onCompleted: sync()

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        StyledText { text: "mode_fan"; color: Colours.primary; font { family: Colours.iconFont; pixelSize: 24 } }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText { text: fan.name; color: Colours.fg; font { pixelSize: 15; bold: true } }
            StyledText { Layout.fillWidth: true; text: fan.subtitle; elide: Text.ElideRight; color: Colours.fgDim; font.pixelSize: 11 }
        }
        ColumnLayout {
            visible: !fan.isGlobal
            spacing: 0
            StyledText {
                Layout.alignment: Qt.AlignRight
                text: fan.info ? Math.round(fan.info.current) + "%" : "—"
                color: Colours.primary
                font { pixelSize: 13; bold: true }
            }
            // Gerçek RPM: sadece sürücü güvenilir değer veriyorsa (bazı modellerde hep 0)
            StyledText {
                readonly property real rpm: Sensors.rpm(fan.fanIndex)
                visible: isFinite(rpm)
                Layout.alignment: Qt.AlignRight
                text: Math.round(rpm) + " RPM"
                color: Colours.fgDim
                font.pixelSize: 10
            }
        }
        Toggle {
            visible: fan.isGlobal
            controlled: true
            checked: FanState.globalOn
            onToggled: v => FanState.setGlobalOn(v)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12
        enabled: fan.allowed
        opacity: fan.allowed ? 1 : 0.35
        Behavior on opacity { Anim {} }

        Segment {
            model: ["Otomatik", "Sabit", "Eğri"]
            controlled: true
            current: fan.mode
            onPicked: i => { fan.mode = i; fan.touch() }
        }

        // Otomatik: NBFC config'inin eğrisi (salt okunur) + kendi eğrine kopyala
        readonly property var cfgCurve: Nbfc.configCurves[fan.isGlobal ? 0 : fan.fanIndex] ?? null
        StyledText {
            visible: fan.mode === 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: parent.cfgCurve
                ? "NBFC config'inin eğrisi kullanılır" + (fan.isGlobal ? " (Fan 1'inki gösteriliyor)" : "") + " · yavaşlama ~" + parent.cfgCurve.hyst + "°C"
                : (Nbfc.configCurves.length > 0 ? "Config eşik tablosu tanımlamıyor; NBFC kendi varsayılanını kullanır." : "Config'teki hazır eğri kullanılır.")
            color: Colours.fgDim
            font.pixelSize: 11
        }
        CurveEditor {
            visible: fan.mode === 0 && parent.cfgCurve !== null
            Layout.fillWidth: true
            readOnly: true
            points: parent.cfgCurve ? parent.cfgCurve.points : []
            smoothCurve: false
            liveTemp: Nbfc.sourceTemp(fan.isGlobal ? 0 : fan.fanIndex, "cpu")
        }
        Btn {
            visible: fan.mode === 0 && parent.cfgCurve !== null
            Layout.fillWidth: true
            icon: "edit"
            text: "Bu eğriyi düzenle"
            onClicked: {
                const c = parent.cfgCurve
                fan.curve = c.points.map(p => ({ t: p.t, s: p.s }))
                fan.smoothCurve = false
                fan.hyst = c.hyst
                fan.src = "cpu"
                fan.mode = 2
                fan.touch()
            }
        }

        SliderRow {
            id: fixedRow
            visible: fan.mode === 1
            label: "Sabit hız"
            value: 0.5
            readout: Math.round(value * 100) + "%"
            onMoved: fan.touch()
        }

        // Sıcaklık kaynağı (sadece harici GPU varsa anlamlı)
        RowLayout {
            visible: fan.mode === 2 && Sensors.hasGpu
            Layout.fillWidth: true
            spacing: 10
            StyledText { text: "Sıcaklık"; color: Colours.fgDim; font.pixelSize: 12 }
            Segment {
                controlled: true
                model: ["CPU", "GPU", "En yüksek"]
                current: Math.max(0, fan.srcKeys.indexOf(fan.src))
                onPicked: i => { fan.src = fan.srcKeys[i]; fan.touch() }
            }
        }

        CurveEditor {
            visible: fan.mode === 2
            Layout.fillWidth: true
            points: fan.curve
            smoothCurve: fan.smoothCurve
            liveTemp: fan.isGlobal ? Nbfc.sourceTemp(0, fan.src) : Nbfc.sourceTemp(fan.fanIndex, fan.src)
            onEdited: pts => { fan.curve = pts; fan.touch() }
            onSmoothPicked: v => { fan.smoothCurve = v; fan.touch() }
        }

        Stepper {
            visible: fan.mode === 2
            Layout.fillWidth: true
            label: "Yavaşlama gecikmesi"
            value: fan.hyst
            from: 0
            to: 10
            unit: "°C"
            onMoved: v => { fan.hyst = v; fan.touch() }
        }
    }
}
