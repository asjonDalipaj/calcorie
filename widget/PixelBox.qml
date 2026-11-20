import QtQuick
import "calpalette.js" as Pal

// A chunky pixel frame: notched corners, one hard shadow, an optional header strip and a
// sparse dither. Children are placed inside the border, so text never sits on the outline.
Item {
    id: root

    property color fill: Pal.paper
    property color line: Pal.ink
    property color headerFill: Pal.peach
    property color ditherColor: Pal.ink
    property real lineWidth: 2
    property real shadowOffset: 4
    property real cut: 6
    property real headerHeight: 0
    property bool shadowOn: true
    property bool dither: false

    default property alias contentData: content.data

    implicitWidth: 120
    implicitHeight: 48

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: false
        renderStrategy: Canvas.Immediate
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.antialiasing = false
            const off = Math.max(0, Math.round(root.shadowOffset))
            const bodyW = Math.max(1, Math.round(root.width - off))
            const bodyH = Math.max(1, Math.round(root.height - off))
            const lw = Math.max(1, Math.round(root.lineWidth))
            const cut = Math.max(0, Math.round(root.cut))
            const head = Math.max(0, Math.min(bodyH, Math.round(root.headerHeight)))

            function pixelPath(x, y, w, h) {
                const c = Math.min(cut, Math.floor(w / 3), Math.floor(h / 3))
                ctx.beginPath()
                ctx.moveTo(x + c, y)
                ctx.lineTo(x + w - c, y)
                ctx.lineTo(x + w - c, y + c)
                ctx.lineTo(x + w, y + c)
                ctx.lineTo(x + w, y + h - c)
                ctx.lineTo(x + w - c, y + h - c)
                ctx.lineTo(x + w - c, y + h)
                ctx.lineTo(x + c, y + h)
                ctx.lineTo(x + c, y + h - c)
                ctx.lineTo(x, y + h - c)
                ctx.lineTo(x, y + c)
                ctx.lineTo(x + c, y + c)
                ctx.closePath()
            }

            if (root.shadowOn && off > 0) {
                pixelPath(off, off, bodyW, bodyH)
                ctx.globalAlpha = 0.24
                ctx.fillStyle = root.line
                ctx.fill()
                ctx.globalAlpha = 1
            }

            pixelPath(0, 0, bodyW, bodyH)
            ctx.fillStyle = root.fill
            ctx.fill()

            if (head > 0) {
                ctx.save()
                pixelPath(0, 0, bodyW, bodyH)
                ctx.clip()
                ctx.fillStyle = root.headerFill
                ctx.fillRect(0, 0, bodyW, head)
                ctx.globalAlpha = 0.22
                ctx.fillStyle = root.line
                ctx.fillRect(0, head - Math.max(1, lw), bodyW, Math.max(1, lw))
                ctx.restore()
            }

            if (root.dither) {
                ctx.save()
                pixelPath(0, 0, bodyW, bodyH)
                ctx.clip()
                ctx.globalAlpha = 0.055
                ctx.fillStyle = root.ditherColor
                for (let y = head + 10; y < bodyH - 6; y += 10)
                    for (let x = 10 + ((y / 10) % 2) * 5; x < bodyW - 8; x += 10)
                        ctx.fillRect(x, y, 2, 2)
                ctx.restore()
            }

            pixelPath(0, 0, bodyW, bodyH)
            ctx.lineWidth = lw
            ctx.strokeStyle = root.line
            ctx.lineJoin = "miter"
            ctx.miterLimit = 2
            ctx.stroke()

            if (head > 0) {
                ctx.fillStyle = root.line
                ctx.globalAlpha = 0.9
                ctx.fillRect(lw, head, bodyW - lw * 2, Math.max(1, lw))
                ctx.globalAlpha = 1
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // The frame's properties are read by the canvas at paint time; ask it to redraw on a change.
    onFillChanged: canvas.requestPaint()
    onLineChanged: canvas.requestPaint()
    onHeaderFillChanged: canvas.requestPaint()
    onDitherColorChanged: canvas.requestPaint()
    onLineWidthChanged: canvas.requestPaint()
    onShadowOffsetChanged: canvas.requestPaint()
    onCutChanged: canvas.requestPaint()
    onHeaderHeightChanged: canvas.requestPaint()
    onShadowOnChanged: canvas.requestPaint()
    onDitherChanged: canvas.requestPaint()

    Item {
        id: content
        anchors.fill: parent
        anchors.leftMargin: Math.round(root.lineWidth)
        anchors.topMargin: Math.round(root.lineWidth)
        anchors.rightMargin: Math.round(root.lineWidth + Math.max(0, root.shadowOffset))
        anchors.bottomMargin: Math.round(root.lineWidth + Math.max(0, root.shadowOffset))
    }
}
