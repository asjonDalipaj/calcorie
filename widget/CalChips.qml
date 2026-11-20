pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "calpalette.js" as Pal

RowLayout {
    id: root

    property var options: []
    property string value: ""
    property real d: 1

    signal picked(string value)

    spacing: Math.round(5 * d)

    Repeater {
        model: root.options

        PixelButton {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(34 * root.d)
            d: root.d
            compact: true
            label: modelData.label
            selected: root.value === modelData.value
            fillColor: modelData.fill !== undefined ? modelData.fill : Pal.paper2
            onClicked: root.picked(modelData.value)
        }
    }
}
