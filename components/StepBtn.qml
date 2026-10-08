import QtQuick
import qs.services

// Round +/- button. Repeats while held down.
Rectangle {
    id: b
    property string icon
    signal activated()

    implicitWidth: 26
    implicitHeight: 26
    radius: 13
    color: ma.pressed ? Colours.primary : Colours.surfaceContainer

    StyledText {
        anchors.centerIn: parent
        text: b.icon
        color: ma.pressed ? Colours.fgOnPrimary : Colours.fg
        font { family: Colours.iconFont; pixelSize: 16 }
    }
    Timer { id: rep; interval: 90; repeat: true; onTriggered: b.activated() }
    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: b.activated()
        onPressAndHold: rep.start()
        onReleased: rep.stop()
        onCanceled: rep.stop()
    }
}
