import QtQuick
import "calpalette.js" as Pal

Item {
    id: root

    property string label: ""
    property string accessibleName: root.label
    property string glyph: ""
    property color fillColor: Pal.paper2
    property color textColor: Pal.ink
    property bool selected: false
    property bool compact: false
    property real d: 1
    property real labelSize: root.compact ? 13 : 14

    signal clicked()

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Accessible.onPressAction: root.clicked()

    implicitWidth: Math.round(84 * d)
    implicitHeight: Math.round((root.compact ? 32 : 38) * d)
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true

    readonly property bool down: mouse.pressed && mouse.containsMouse

    PixelBox {
        anchors.fill: parent
        fill: root.selected ? Pal.lemon : root.fillColor
        line: root.activeFocus ? Pal.tomato : Pal.ink
        lineWidth: Math.max(1, Math.round(2 * root.d))
        shadowOffset: root.down ? Math.round(1 * root.d) : Math.round(3 * root.d)
        cut: Math.round(3 * root.d)
    }

    Row {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.down ? 0 : Math.round(-1 * root.d)
        anchors.verticalCenterOffset: root.down ? Math.round(1 * root.d) : 0
        spacing: Math.round(5 * root.d)

        Text {
            visible: root.glyph.length > 0
            text: root.glyph
            color: root.textColor
            font.family: "Silkscreen"
            font.pixelSize: Math.round(root.labelSize * root.d)
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.label
            color: root.textColor
            font.family: "Silkscreen"
            font.pixelSize: Math.round(root.labelSize * root.d)
            font.letterSpacing: Math.round(0.6 * root.d)
            renderType: Text.NativeRendering
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus()
            root.clicked()
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.clicked()
            event.accepted = true
        }
    }

    scale: root.down ? 0.97 : 1
    Behavior on scale {
        enabled: root.down
        NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
    }
}
