import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.components
import qs.services

// Son 10 dakika: CPU / GPU sıcaklığı (°C) ve ortalama fan hızı (%) aynı 0–100 ölçeğinde
Card {
    id: card
    title: "Son 10 dakika"

    // Pencere gizliyken veri kaydı sürer ama grafik hesaplanmaz
    readonly property var h: Nbfc.uiVisible ? Nbfc.history : []
    readonly property double end: h.length ? h[h.length - 1].t : Date.now()
    function px(t) { return (t - (end - Nbfc.historyMs)) / Nbfc.historyMs * plot.width }
    function py(v) { return plot.height * (1 - Math.max(0, Math.min(100, v)) / 100) }
    // NaN olan örneklerde çizgiyi böl (GPU uykudayken vb.)
    function lines(key) {
        const out = []
        let cur = []
        for (const s of h) {
            const v = s[key]
            if (isFinite(v)) cur.push(Qt.point(px(s.t), py(v)))
            else if (cur.length) { out.push(cur); cur = [] }
        }
        if (cur.length) out.push(cur)
        return out.filter(l => l.length > 1)
    }
    readonly property var series: [
        { key: "cpu", label: "CPU °C", color: Colours.primary, show: true },
        { key: "gpu", label: "GPU °C", color: Colours.sky, show: Sensors.hasGpu },
        { key: "fan", label: "Fan %", color: Colours.fgDim, show: true }
    ]

    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        Repeater {
            model: card.series.filter(s => s.show)
            RowLayout {
                required property var modelData
                spacing: 6
                Row {
                    spacing: 2
                    Repeater {
                        model: modelData.key === "fan" ? 3 : 1    // fan çizgisi kesikli
                        Rectangle { width: modelData.key === "fan" ? 4 : 14; height: 3; radius: 1.5; color: parent.parent.modelData.color }
                    }
                }
                StyledText { text: modelData.label; color: Colours.fgDim; font.pixelSize: 11 }
            }
        }
        Item { Layout.fillWidth: true }
        StyledText {
            visible: card.h.length < 2
            text: "Veri toplanıyor…"
            color: Colours.fgDim
            font.pixelSize: 11
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 140
        radius: 14
        color: Colours.surfaceHigh

        Item {
            id: plot
            anchors { fill: parent; leftMargin: 30; rightMargin: 12; topMargin: 10; bottomMargin: 20 }

            Repeater {
                model: [0, 50, 100]
                Item {
                    width: plot.width; height: 1
                    y: card.py(modelData)
                    Rectangle { anchors.fill: parent; color: Colours.outline; opacity: 0.4 }
                    StyledText { x: -26; y: -height / 2; text: modelData; color: Colours.fgDim; font.pixelSize: 9 }
                }
            }
            // Güvenlik sınırı
            Rectangle {
                width: plot.width; height: 1
                y: card.py(Nbfc.safety)
                color: Colours.error
                opacity: 0.7
            }
            Repeater {
                model: ["-10 dk", "-5 dk", "şimdi"]
                StyledText {
                    x: index / 2 * plot.width - (index === 0 ? 0 : index === 2 ? width : width / 2)
                    y: plot.height + 4
                    text: modelData
                    color: Colours.fgDim
                    font.pixelSize: 9
                }
            }

            Repeater {
                model: card.series.filter(s => s.show)
                Shape {
                    required property var modelData
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: modelData.color
                        strokeWidth: 2
                        strokeStyle: modelData.key === "fan" ? ShapePath.DashLine : ShapePath.SolidLine
                        dashPattern: [3, 3]
                        fillColor: "transparent"
                        joinStyle: ShapePath.RoundJoin
                        capStyle: ShapePath.RoundCap
                        PathMultiline { paths: card.lines(modelData.key) }
                    }
                }
            }
        }
    }
}
