import QtQuick
import QtQuick.Layouts
import "calpalette.js" as Pal

RowLayout {
    id: root

    property string label: ""
    property string suffix: ""
    property int value: 0
    property int from: 0
    property int to: 999
    property int step: 1
    property real d: 1

    signal changed(int value)

    implicitHeight: Math.round(38 * d)
    spacing: Math.round(5 * d)

    Text {
        Layout.fillWidth: true
        text: root.label
        color: Pal.ink
        font.family: "Pixelify Sans"
        font.pixelSize: Math.round(14 * d)
        font.weight: Font.Medium
        renderType: Text.NativeRendering
        elide: Text.ElideRight
    }

    PixelButton {
        d: root.d
        width: Math.round(30 * root.d)
        implicitWidth: width
        implicitHeight: Math.round(32 * root.d)
        label: "−"
        compact: true
        fillColor: Pal.paper2
        onClicked: {
            const next = Math.max(root.from, root.value - root.step)
            if (next !== root.value)
                root.changed(next)
        }
    }

    Item {
        Layout.preferredWidth: Math.round(62 * root.d)
        Layout.fillHeight: true

        Text {
            anchors.centerIn: parent
            text: root.value + root.suffix
            color: Pal.ink
            font.family: "Silkscreen"
            font.pixelSize: Math.round(15 * root.d)
            renderType: Text.NativeRendering
        }
    }

    PixelButton {
        d: root.d
        width: Math.round(30 * root.d)
        implicitWidth: width
        implicitHeight: Math.round(32 * root.d)
        label: "+"
        compact: true
        fillColor: Pal.mint
        onClicked: {
            const next = Math.min(root.to, root.value + root.step)
            if (next !== root.value)
                root.changed(next)
        }
    }
}
