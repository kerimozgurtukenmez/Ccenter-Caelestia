import QtQuick

Item {
    id: w
    property real hue: 0              // 0..1
    property real sat: 0              // 0..1
    signal picked(real h, real s)

    implicitWidth: 220
    implicitHeight: 220

    // Çark önceden üretilmiş görsel (wheel.png, bu dosyayla aynı klasörde)
    Image {
        anchors.fill: parent
        source: "wheel.png"
        smooth: true
        mipmap: true
    }

    Rectangle {
        readonly property real rad: w.width / 2
        width: 22; height: 22; radius: 11
        x: rad + Math.cos(w.hue * 2 * Math.PI) * w.sat * rad - width / 2
        y: rad + Math.sin(w.hue * 2 * Math.PI) * w.sat * rad - height / 2
        color: Qt.hsva(w.hue, w.sat, 1, 1)
        border { width: 3; color: "white" }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        function pick(m) {
            const r = width / 2
            const dx = m.x - r, dy = m.y - r
            w.picked((Math.atan2(dy, dx) / (2 * Math.PI) + 1) % 1, Math.min(1, Math.sqrt(dx * dx + dy * dy) / r))
        }
        onPressed: m => pick(m)
        onPositionChanged: m => pick(m)
    }
}
