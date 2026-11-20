import QtQuick
import "calpalette.js" as Pal

Item {
    id: root

    property bool checked: false
    property real d: 1
    property string accessibleName: ""

    signal toggled()

    implicitWidth: Math.round(18 * d)
    implicitHeight: Math.round(18 * d)
    activeFocusOnTab: true

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.accessibleName
    Accessible.checkable: true
    Accessible.checked: root.checked
    Accessible.onToggleAction: root.toggled()

    PixelBox {
        anchors.fill: parent
        fill: root.checked ? Pal.mint : Pal.paper
        line: root.activeFocus ? Pal.tomato : Pal.ink
        lineWidth: Math.max(1, Math.round(2 * root.d))
        shadowOffset: 0
        cut: Math.round(2 * root.d)
    }

    Canvas {
        visible: root.checked
        anchors.fill: parent
        antialiasing: false
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.antialiasing = false
            ctx.strokeStyle = Pal.ink
            ctx.lineWidth = Math.max(2, Math.round(2 * root.d))
            ctx.lineCap = "square"
            ctx.lineJoin = "miter"
            ctx.beginPath()
            ctx.moveTo(root.width * 0.24, root.height * 0.52)
            ctx.lineTo(root.width * 0.43, root.height * 0.72)
            ctx.lineTo(root.width * 0.78, root.height * 0.28)
            ctx.stroke()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus()
            root.toggled()
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.toggled()
            event.accepted = true
        }
    }
}
