import QtQuick
import QtQuick.Layouts

RowLayout {
    id: tr
    property string icon: ""
    property string label
    property string sub
    property alias checked: tg.checked
    property bool controlled: false
    signal toggled(bool v)

    Layout.fillWidth: true
    spacing: 12

    Text { visible: tr.icon !== ""; text: tr.icon; color: Colours.primary; font { family: Colours.iconFont; pixelSize: 22 } }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text { text: tr.label; color: Colours.fg; font.pixelSize: 14 }
        Text { Layout.fillWidth: true; text: tr.sub; wrapMode: Text.WordWrap; color: Colours.fgDim; font.pixelSize: 11 }
    }
    Toggle { id: tg; controlled: tr.controlled; onToggled: v => tr.toggled(v) }
}
