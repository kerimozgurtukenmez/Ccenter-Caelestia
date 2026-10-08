import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// Sıcaklık -> fan hızı eğrisi. Noktalar [{ t: °C, s: % }] ve sıcaklığa göre sıralı.
ColumnLayout {
    id: ed
    property var points: []
    property bool smoothCurve: true
    property real liveTemp: NaN
    property bool readOnly: false            // sadece göster (config eğrisi önizlemesi)
    property int selected: 0
    readonly property int tMin: 30
    readonly property int tMax: 100
    readonly property int selIndex: Math.max(0, Math.min(selected, points.length - 1))
    readonly property var sel: points.length > 0 ? points[selIndex] : ({ t: 0, s: 0 })
    signal edited(var pts)
    signal smoothPicked(bool v)

    spacing: 8

    function px(t) { return (t - tMin) / (tMax - tMin) * plot.width }
    function py(s) { return plot.height * (1 - s / 100) }
    function tAt(x) { return tMin + x / plot.width * (tMax - tMin) }
    function sAt(y) { return (1 - y / plot.height) * 100 }
    function copy() { return points.map(q => ({ t: q.t, s: q.s })) }

    function movePoint(i, t, s) {
        const p = points
        if (i < 0 || i >= p.length) return
        const lo = i > 0 ? p[i - 1].t + 1 : tMin
        const hi = i < p.length - 1 ? p[i + 1].t - 1 : tMax
        t = Math.max(lo, Math.min(hi, Math.round(t)))
        s = Math.max(0, Math.min(100, Math.round(s)))
        if (t === p[i].t && s === p[i].s) return
        const a = copy()
        a[i] = { t: t, s: s }
        edited(a)
    }
    // En geniş boşluğun ortasına yeni nokta ekler
    function add() {
        if (points.length >= 12) return
        const a = copy()
        let best = -1, gap = 1, at = a.length
        for (let k = 0; k < a.length - 1; k++) {
            const g = a[k + 1].t - a[k].t
            if (g > gap) { gap = g; best = k; at = k + 1 }
        }
        const tail = tMax - a[a.length - 1].t
        if (tail > gap) { gap = tail; best = a.length - 1; at = a.length }
        if (best < 0) return
        const t = a[best].t + Math.floor(gap / 2)
        const s = at < a.length ? Math.round((a[best].s + a[at].s) / 2) : a[best].s
        a.splice(at, 0, { t: t, s: s })
        selected = at
        edited(a)
    }
    function removeSelected() {
        if (points.length <= 1) return
        const a = copy()
        a.splice(selIndex, 1)
        selected = Math.max(0, selIndex - 1)
        edited(a)
    }
    function reset() {
        selected = 0
        edited([{ t: 45, s: 20 }, { t: 55, s: 40 }, { t: 65, s: 60 }, { t: 75, s: 80 }, { t: 85, s: 100 }])
    }

    // Çizgi parçaları (düzgün: düz çizgiler, basamaklı: yatay + dikey)
    readonly property var segs: {
        const out = []
        const p = points
        if (!p || p.length === 0) return out
        out.push({ x1: 0, y1: py(p[0].s), x2: px(p[0].t), y2: py(p[0].s) })
        for (let i = 1; i < p.length; i++) {
            if (smoothCurve) {
                out.push({ x1: px(p[i - 1].t), y1: py(p[i - 1].s), x2: px(p[i].t), y2: py(p[i].s) })
            } else {
                out.push({ x1: px(p[i - 1].t), y1: py(p[i - 1].s), x2: px(p[i].t), y2: py(p[i - 1].s) })
                out.push({ x1: px(p[i].t), y1: py(p[i - 1].s), x2: px(p[i].t), y2: py(p[i].s) })
            }
        }
        const l = p[p.length - 1]
        out.push({ x1: px(l.t), y1: py(l.s), x2: plot.width, y2: py(l.s) })
        return out
    }

    Segment {
        visible: !ed.readOnly
        controlled: true
        model: ["Düzgün geçiş", "Basamaklı"]
        current: ed.smoothCurve ? 0 : 1
        onPicked: i => ed.smoothPicked(i === 0)
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 172
        radius: 14
        color: Colours.surfaceHigh

        Item {
            id: plot
            anchors { fill: parent; leftMargin: 34; rightMargin: 14; topMargin: 14; bottomMargin: 24 }

            Repeater {
                model: [0, 25, 50, 75, 100]
                Item {
                    width: plot.width; height: 1
                    y: ed.py(modelData)
                    Rectangle { anchors.fill: parent; color: Colours.outline; opacity: 0.4 }
                    StyledText { x: -30; y: -height / 2; text: modelData + "%"; color: Colours.fgDim; font.pixelSize: 9 }
                }
            }
            Repeater {
                model: [30, 40, 50, 60, 70, 80, 90, 100]
                Item {
                    x: ed.px(modelData); width: 1; height: plot.height
                    Rectangle { anchors.fill: parent; color: Colours.outline; opacity: 0.25 }
                    StyledText {
                        visible: modelData % 20 === 0
                        x: -width / 2; y: plot.height + 5
                        text: modelData + "°"; color: Colours.fgDim; font.pixelSize: 9
                    }
                }
            }

            // Anlık sıcaklık
            Rectangle {
                visible: isFinite(ed.liveTemp) && ed.liveTemp >= ed.tMin && ed.liveTemp <= ed.tMax
                x: ed.px(ed.liveTemp) - 1; width: 2; height: plot.height
                color: Colours.fg; opacity: 0.55
            }

            Repeater {
                model: ed.segs
                Rectangle {
                    readonly property real dx: modelData.x2 - modelData.x1
                    readonly property real dy: modelData.y2 - modelData.y1
                    x: modelData.x1
                    y: modelData.y1 - height / 2
                    width: Math.sqrt(dx * dx + dy * dy)
                    height: 3
                    radius: 1.5
                    color: Colours.primary
                    transformOrigin: Item.Left
                    rotation: Math.atan2(dy, dx) * 180 / Math.PI
                }
            }

            // Sürüklenebilir noktalar (model = sayı: sürüklerken bileşen yeniden oluşmasın)
            Repeater {
                model: ed.points.length
                Item {
                    readonly property var pt: ed.points[index]
                    readonly property bool chosen: index === ed.selIndex
                    width: 28; height: 28
                    x: pt ? ed.px(pt.t) - width / 2 : 0
                    y: pt ? ed.py(pt.s) - height / 2 : 0
                    Rectangle {
                        anchors.centerIn: parent
                        width: ed.readOnly ? 10 : (chosen ? 18 : 14); height: width; radius: width / 2
                        color: chosen ? Colours.primary : Colours.surfaceHigh
                        border { width: 3; color: Colours.primary }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !ed.readOnly
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: ed.selected = index
                        onPositionChanged: m => {
                            const p = mapToItem(plot, m.x, m.y)
                            ed.movePoint(index, ed.tAt(p.x), ed.sAt(p.y))
                        }
                    }
                }
            }
        }
    }

    StyledText {
        visible: !ed.readOnly
        text: "Nokta " + (ed.selIndex + 1) + " / " + ed.points.length + " · sürükle ya da aşağıdan ayarla"
        color: Colours.fgDim
        font.pixelSize: 11
    }
    Stepper {
        visible: !ed.readOnly
        Layout.fillWidth: true
        label: "Sıcaklık"; unit: "°C"; from: ed.tMin; to: ed.tMax
        value: ed.sel.t
        onMoved: v => ed.movePoint(ed.selIndex, v, ed.sel.s)
    }
    Stepper {
        visible: !ed.readOnly
        Layout.fillWidth: true
        label: "Fan hızı"; unit: "%"; from: 0; to: 100
        value: ed.sel.s
        onMoved: v => ed.movePoint(ed.selIndex, ed.sel.t, v)
    }
    RowLayout {
        visible: !ed.readOnly
        Layout.fillWidth: true
        spacing: 8
        Btn {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            icon: "add"; text: "Ekle"
            enabled: ed.points.length < 12
            opacity: enabled ? 1 : 0.4
            onClicked: ed.add()
        }
        Btn {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            icon: "delete"; text: "Sil"
            enabled: ed.points.length > 1
            opacity: enabled ? 1 : 0.4
            onClicked: ed.removeSelected()
        }
        Btn { icon: "restart_alt"; onClicked: ed.reset() }
    }
}
