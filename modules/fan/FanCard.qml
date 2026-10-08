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
    property alias globalOn: tog.checked
    property var info: null                  // Nbfc.fans[i] (global kartta null)
    property bool synced: false
    property bool smoothCurve: true
    property string src: "cpu"               // Eğri modunda bakılan sıcaklık: cpu | gpu | max
    readonly property var srcKeys: ["cpu", "gpu", "max"]
    property int hyst: 3                     // Eğri: yavaşlamadan önce sıcaklığın inmesi gereken derece
    property var curve: [{ t: 45, s: 20 }, { t: 55, s: 40 }, { t: 65, s: 60 }, { t: 75, s: 80 }, { t: 85, s: 100 }]
    readonly property bool allowed: isGlobal ? tog.checked : active
    // mode: 0 Otomatik, 1 Sabit, 2 Eğri
    readonly property var st: ({ mode: mode.current, fixed: fixedRow.value, curve: fan.curve, smooth: fan.smoothCurve, src: fan.src, hyst: fan.hyst })
    signal edited()                          // kullanıcı bir şeyi değiştirdi (400 ms bekleyip bir kez)

    function touch() { debounce.restart() }

    // Kayıtlı ayarı karta yükler (komut göndermez; uygulamayı FanPage yapar)
    function restore(s) {
        synced = true
        if (s.curve) curve = s.curve
        smoothCurve = s.smooth
        src = s.src
        hyst = s.hyst
        fixedRow.value = s.fixed
        mode.current = s.mode
    }
    Timer { id: debounce; interval: 400; onTriggered: fan.edited() }

    // İlk durum okunduğunda kartı fanın gerçek durumuna eşitle (komut göndermez)
    onInfoChanged: {
        if (!info || synced || isGlobal) return
        synced = true
        mode.current = info.auto ? 0 : 1
        if (!info.auto) fixedRow.value = Math.max(0, Math.min(1, info.target / 100))
    }

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
        StyledText {
            visible: !fan.isGlobal
            text: fan.info ? Math.round(fan.info.current) + "%" : "—"
            color: Colours.primary
            font { pixelSize: 13; bold: true }
        }
        Toggle { id: tog; visible: fan.isGlobal }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12
        enabled: fan.allowed
        opacity: fan.allowed ? 1 : 0.35
        Behavior on opacity { Anim {} }

        Segment { id: mode; model: ["Otomatik", "Sabit", "Eğri"]; onPicked: fan.touch() }

        // Otomatik: NBFC config'inin eğrisi (salt okunur) + kendi eğrine kopyala
        readonly property var cfgCurve: Nbfc.configCurves[fan.isGlobal ? 0 : fan.fanIndex] ?? null
        StyledText {
            visible: mode.current === 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: parent.cfgCurve
                ? "NBFC config'inin eğrisi kullanılır" + (fan.isGlobal ? " (Fan 1'inki gösteriliyor)" : "") + " · yavaşlama ~" + parent.cfgCurve.hyst + "°C"
                : (Nbfc.configCurves.length > 0 ? "Config eşik tablosu tanımlamıyor; NBFC kendi varsayılanını kullanır." : "Config'teki hazır eğri kullanılır.")
            color: Colours.fgDim
            font.pixelSize: 11
        }
        CurveEditor {
            visible: mode.current === 0 && parent.cfgCurve !== null
            Layout.fillWidth: true
            readOnly: true
            points: parent.cfgCurve ? parent.cfgCurve.points : []
            smoothCurve: false
            liveTemp: Nbfc.sourceTemp(fan.isGlobal ? 0 : fan.fanIndex, "cpu")
        }
        Btn {
            visible: mode.current === 0 && parent.cfgCurve !== null
            Layout.fillWidth: true
            icon: "edit"
            text: "Bu eğriyi düzenle"
            onClicked: {
                const c = parent.cfgCurve
                fan.curve = c.points.map(p => ({ t: p.t, s: p.s }))
                fan.smoothCurve = false
                fan.hyst = c.hyst
                fan.src = "cpu"
                mode.current = 2
                fan.touch()
            }
        }

        SliderRow {
            id: fixedRow
            visible: mode.current === 1
            label: "Sabit hız"
            value: 0.5
            readout: Math.round(value * 100) + "%"
            onMoved: fan.touch()
        }

        // Sıcaklık kaynağı (sadece harici GPU varsa anlamlı)
        RowLayout {
            visible: mode.current === 2 && Sensors.hasGpu
            Layout.fillWidth: true
            spacing: 10
            StyledText { text: "Sıcaklık"; color: Colours.fgDim; font.pixelSize: 12 }
            Segment {
                model: ["CPU", "GPU", "En yüksek"]
                current: Math.max(0, fan.srcKeys.indexOf(fan.src))
                onPicked: i => { fan.src = fan.srcKeys[i]; fan.touch() }
            }
        }

        CurveEditor {
            visible: mode.current === 2
            Layout.fillWidth: true
            points: fan.curve
            smoothCurve: fan.smoothCurve
            liveTemp: fan.isGlobal ? Nbfc.sourceTemp(0, fan.src) : Nbfc.sourceTemp(fan.fanIndex, fan.src)
            onEdited: pts => { fan.curve = pts; fan.touch() }
            onSmoothPicked: v => { fan.smoothCurve = v; fan.touch() }
        }

        Stepper {
            visible: mode.current === 2
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
